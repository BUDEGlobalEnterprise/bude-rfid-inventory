import 'package:bude_inventory/core/hardware/device_probe.dart';
import 'package:bude_inventory/core/hardware/entities/device_info.dart';
import 'package:bude_inventory/core/hardware/hardware_manager.dart';
import 'package:bude_inventory/core/hardware/hardware_registry.dart';
import 'package:bude_inventory/core/hardware/providers.dart';
import 'package:bude_inventory/core/hardware/vendors/demo/demo_rfid_adapter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedProbe implements DeviceProbe {
  final DeviceInfo info;
  const _FixedProbe(this.info);

  @override
  Future<DeviceInfo> probe() async => info;
}

void main() {
  tearDown(() {
    HardwareRegistry.instance.replaceAll([]);
  });

  test('lookup can access demo RFID through rfidAdapterProvider', () async {
    final manager = HardwareManager(
      registry: HardwareRegistry.instance,
      probe: const _FixedProbe(
        DeviceInfo(manufacturer: 'unknown', model: 'unknown'),
      ),
      fallbackRfid: DemoRfidAdapter(),
    );
    await manager.initialize();

    final container = ProviderContainer(
      overrides: [hardwareManagerProvider.overrideWithValue(manager)],
    );
    addTearDown(container.dispose);
    addTearDown(manager.dispose);

    final rfid = container.read(rfidAdapterProvider);

    expect(rfid, isA<DemoRfidAdapter>());
    expect(rfid?.vendor, 'demo');
  });
}
