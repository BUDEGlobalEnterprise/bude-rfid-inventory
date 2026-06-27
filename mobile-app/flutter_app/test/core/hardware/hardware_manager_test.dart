import 'package:bude_inventory/core/hardware/adapters/barcode_adapter.dart';
import 'package:bude_inventory/core/hardware/adapters/hardware_exceptions.dart';
import 'package:bude_inventory/core/hardware/device_probe.dart';
import 'package:bude_inventory/core/hardware/entities/device_info.dart';
import 'package:bude_inventory/core/hardware/entities/scan_event.dart';
import 'package:bude_inventory/core/hardware/hardware_manager.dart';
import 'package:bude_inventory/core/hardware/hardware_registry.dart';
import 'package:bude_inventory/core/hardware/providers.dart';
import 'package:bude_inventory/core/hardware/vendors/chainway/chainway_adapters.dart';
import 'package:bude_inventory/core/hardware/vendors/demo/demo_rfid_adapter.dart';
import 'package:bude_inventory/core/hardware/vendors/registered_plugins.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedProbe implements DeviceProbe {
  final DeviceInfo info;
  const _FixedProbe(this.info);

  @override
  Future<DeviceInfo> probe() async => info;
}

class _FakeBarcodeAdapter implements BarcodeAdapter {
  @override
  String get vendor => 'fake';
  bool disposed = false;

  @override
  Stream<ScanEvent> get events => const Stream.empty();
  @override
  bool get supportsContinuousScan => true;
  @override
  Future<void> startScan() async {}
  @override
  Future<void> stopScan() async {}
  @override
  Future<ScanEvent?> scanSingle({
    Duration timeout = const Duration(seconds: 30),
  }) async =>
      null;
  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  tearDown(() {
    HardwareRegistry.instance.replaceAll([]);
  });

  test('initialize falls back to camera when no vendor plugin matches',
      () async {
    final fallback = _FakeBarcodeAdapter();
    final manager = HardwareManager(
      registry: HardwareRegistry.instance,
      probe: const _FixedProbe(
        DeviceInfo(manufacturer: 'unknown', model: 'unknown'),
      ),
      fallbackBarcode: fallback,
    );

    await manager.initialize();

    expect(manager.barcode, same(fallback));
    expect(manager.rfid, isNull);
    expect(manager.deviceInfo!.manufacturer, 'unknown');
  });

  test('initialize uses fallback RFID when no real RFID is selected', () async {
    final manager = HardwareManager(
      registry: HardwareRegistry.instance,
      probe: const _FixedProbe(
        DeviceInfo(manufacturer: 'unknown', model: 'unknown'),
      ),
      fallbackRfid: DemoRfidAdapter(),
    );

    await manager.initialize();

    expect(manager.rfid, isA<DemoRfidAdapter>());
    expect(manager.rfid!.vendor, 'demo');
  });

  test('bootstrap can disable demo RFID for production behavior', () async {
    final manager = await bootstrapHardwareManager(
      probe: const _FixedProbe(
        DeviceInfo(manufacturer: 'unknown', model: 'unknown'),
      ),
      enableDemoRfid: false,
    );

    expect(manager.rfid, isNull);
    await manager.dispose();
  });

  test('bootstrap can enable demo RFID for development behavior', () async {
    final manager = await bootstrapHardwareManager(
      probe: const _FixedProbe(
        DeviceInfo(manufacturer: 'unknown', model: 'unknown'),
      ),
      enableDemoRfid: true,
    );

    expect(manager.rfid, isA<DemoRfidAdapter>());
    await manager.dispose();
  });

  test('initialize picks matching vendor plugin over fallback', () async {
    registerBuiltInHardwarePlugins();
    final fallback = _FakeBarcodeAdapter();
    final manager = HardwareManager(
      registry: HardwareRegistry.instance,
      probe: const _FixedProbe(
        DeviceInfo(manufacturer: 'Chainway', model: 'C72'),
      ),
      fallbackBarcode: fallback,
    );

    await manager.initialize();

    expect(manager.barcode, isA<ChainwayBarcodeAdapter>());
    expect(manager.rfid, isNotNull);
    expect(manager.rfid!.vendor, 'chainway');
  });

  test('first matching plugin wins when multiple registered', () async {
    final calls = <String>[];
    HardwareRegistry.instance.replaceAll([
      HardwarePlugin(
        vendor: 'a',
        matches: (info) {
          calls.add('a');
          return false;
        },
      ),
      HardwarePlugin(
        vendor: 'b',
        matches: (info) {
          calls.add('b');
          return true;
        },
        barcodeFactory: () => _FakeBarcodeAdapter(),
      ),
      HardwarePlugin(
        vendor: 'c',
        matches: (info) {
          calls.add('c');
          return true;
        },
        barcodeFactory: () => _FakeBarcodeAdapter(),
      ),
    ]);

    final manager = HardwareManager(
      registry: HardwareRegistry.instance,
      probe: const _FixedProbe(
        DeviceInfo(manufacturer: 'whatever', model: 'x'),
      ),
    );

    await manager.initialize();

    expect(calls, ['a', 'b']); // c is never asked
    expect(manager.barcode, isNotNull);
  });

  test('re-initializing disposes previous adapters', () async {
    final first = _FakeBarcodeAdapter();
    final second = _FakeBarcodeAdapter();
    var produced = 0;
    HardwareRegistry.instance.replaceAll([
      HardwarePlugin(
        vendor: 'fake',
        matches: (_) => true,
        barcodeFactory: () {
          produced++;
          return produced == 1 ? first : second;
        },
      ),
    ]);

    final manager = HardwareManager(
      registry: HardwareRegistry.instance,
      probe: const _FixedProbe(
        DeviceInfo(manufacturer: 'fake', model: 'x'),
      ),
    );

    await manager.initialize();
    expect(manager.barcode, same(first));

    await manager.initialize();
    expect(first.disposed, isTrue);
    expect(manager.barcode, same(second));
  });

  test('Honeywell plugin provides barcode but no rfid', () async {
    registerBuiltInHardwarePlugins();
    final manager = HardwareManager(
      registry: HardwareRegistry.instance,
      probe: const _FixedProbe(
        DeviceInfo(manufacturer: 'Honeywell', model: 'CT40'),
      ),
    );

    await manager.initialize();

    expect(manager.barcode, isNotNull);
    expect(manager.barcode!.vendor, 'honeywell');
    expect(manager.rfid, isNull);
  });

  test('stub adapter throws VendorSdkUnavailableException with hint', () async {
    final adapter = ChainwayBarcodeAdapter();
    expect(
      () => adapter.startScan(),
      throwsA(
        isA<VendorSdkUnavailableException>()
            .having((e) => e.vendor, 'vendor', 'chainway')
            .having((e) => e.hint, 'hint', contains('Chainway')),
      ),
    );
  });

  test('RfidAdapter stub for Chainway exposes correct vendor', () {
    final rfid = ChainwayRfidAdapter();
    expect(rfid.vendor, 'chainway');
    expect(
      () => rfid.connect(),
      throwsA(isA<VendorSdkUnavailableException>()),
    );
  });

  test('Generic UHF plugin matches devices with BLE RFID capability', () async {
    registerBuiltInHardwarePlugins();
    final manager = HardwareManager(
      registry: HardwareRegistry.instance,
      probe: const _FixedProbe(
        DeviceInfo(
          manufacturer: 'unknown',
          model: 'rugged-tablet',
          capabilities: {HardwareCapability.bluetoothRfidReader},
        ),
      ),
    );

    await manager.initialize();
    expect(manager.rfid, isNotNull);
    expect(manager.rfid!.vendor, 'generic');
  });

  test('disposed returns false from RfidAdapter.isConnected even after errors',
      () async {
    final rfid = ChainwayRfidAdapter();
    expect(rfid.isConnected, isFalse);
    await rfid.dispose();
    expect(rfid.isConnected, isFalse);
  });
}
