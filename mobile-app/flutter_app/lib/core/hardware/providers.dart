import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adapters/barcode_adapter.dart';
import 'adapters/rfid_adapter.dart';
import 'camera/camera_barcode_adapter.dart';
import 'device_probe.dart';
import 'hardware_manager.dart';
import 'hardware_registry.dart';
import 'probes/android_device_probe.dart';

/// Override in `main.dart` after `HardwareManager.initialize()` has run, so
/// consumers always get an initialized instance.
final hardwareManagerProvider = Provider<HardwareManager>((ref) {
  throw UnimplementedError(
    'Override hardwareManagerProvider in ProviderScope after initialize().',
  );
});

/// Convenience accessors so callers don't have to remember to null-check both
/// the manager and the selected adapter.
final barcodeAdapterProvider = Provider<BarcodeAdapter?>((ref) {
  return ref.watch(hardwareManagerProvider).barcode;
});

final rfidAdapterProvider = Provider<RfidAdapter?>((ref) {
  return ref.watch(hardwareManagerProvider).rfid;
});

/// Build + initialize the manager. Called once from `main.dart`.
///
/// When [probe] is omitted, picks `AndroidDeviceProbe` on Android (so
/// vendor detection works on real devices) and `DefaultDeviceProbe`
/// everywhere else. Tests can override by passing a fixed probe.
Future<HardwareManager> bootstrapHardwareManager({
  DeviceProbe? probe,
}) async {
  final effectiveProbe = probe ??
      (defaultTargetPlatform == TargetPlatform.android
          ? AndroidDeviceProbe()
          : const DefaultDeviceProbe());
  final manager = HardwareManager(
    registry: HardwareRegistry.instance,
    probe: effectiveProbe,
    fallbackBarcode: CameraBarcodeAdapter(),
  );
  await manager.initialize();
  return manager;
}
