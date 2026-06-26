import 'adapters/barcode_adapter.dart';
import 'adapters/device_adapter.dart';
import 'adapters/rfid_adapter.dart';
import 'device_probe.dart';
import 'entities/device_info.dart';
import 'hardware_registry.dart';

/// Central orchestrator for hardware access. Business code never touches
/// vendor SDKs directly — it asks the [HardwareManager] for a
/// [BarcodeAdapter] / [RfidAdapter] and the manager picks the right
/// implementation based on the detected device.
///
/// Resolution order for both adapter kinds:
///   1. A registered [HardwarePlugin] whose `matches(deviceInfo)` returns true.
///   2. The optional fallback adapter for that kind (camera for barcode,
///      demo RFID in non-production builds).
///   3. Otherwise: null.
class HardwareManager {
  final HardwareRegistry registry;
  final DeviceProbe probe;
  final DeviceAdapter? deviceAdapter;

  /// Always-available barcode adapter. Camera scanner is wired in
  /// `main.dart` so that even unknown devices can scan via the rear camera.
  final BarcodeAdapter? fallbackBarcode;
  final RfidAdapter? fallbackRfid;

  DeviceInfo? _deviceInfo;
  BarcodeAdapter? _barcode;
  RfidAdapter? _rfid;
  bool _initialized = false;

  HardwareManager({
    required this.registry,
    required this.probe,
    this.deviceAdapter,
    this.fallbackBarcode,
    this.fallbackRfid,
  });

  DeviceInfo? get deviceInfo => _deviceInfo;
  BarcodeAdapter? get barcode => _barcode;
  RfidAdapter? get rfid => _rfid;
  bool get isInitialized => _initialized;

  /// Probe the device and pick adapters. Safe to call once at app start —
  /// subsequent calls re-probe and rebuild adapters (use sparingly; it
  /// disposes the previous instances).
  Future<void> initialize() async {
    if (_initialized) {
      await _disposeAdapters();
    }
    final info = await probe.probe();
    _deviceInfo = info;
    final plugin = registry.findFor(info);

    _barcode = plugin?.barcodeFactory?.call() ?? fallbackBarcode;
    _rfid = plugin?.rfidFactory?.call() ?? fallbackRfid;

    _initialized = true;
  }

  Future<void> dispose() async {
    await _disposeAdapters();
    _initialized = false;
    _deviceInfo = null;
  }

  Future<void> _disposeAdapters() async {
    final b = _barcode;
    final r = _rfid;
    _barcode = null;
    _rfid = null;
    await b?.dispose();
    await r?.dispose();
  }
}
