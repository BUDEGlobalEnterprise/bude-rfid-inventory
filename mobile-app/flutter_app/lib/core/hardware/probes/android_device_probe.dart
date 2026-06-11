import 'package:flutter/services.dart';

import '../device_probe.dart';
import '../entities/device_info.dart';

/// Reads Android `Build.MANUFACTURER`, `Build.MODEL`,
/// `Build.VERSION.RELEASE`, and a small set of hardware capability flags
/// via the `bude.hardware/probe` method channel.
///
/// The native Kotlin handler ships as a hand-paste artifact under
/// `lib/core/hardware/probes/ANDROID_NATIVE_INSTALL.md` because the
/// `android/` folder is created lazily by `flutter create`.
///
/// On `MissingPluginException` (handler not wired yet) this probe falls
/// back to "unknown" rather than crashing — the camera fallback adapter
/// stays usable while integration is in progress.
class AndroidDeviceProbe implements DeviceProbe {
  static const _channel = MethodChannel('bude.hardware/probe');

  @override
  Future<DeviceInfo> probe() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('probe');
      if (result == null) return _fallback();

      final manufacturer = (result['manufacturer'] as String?) ?? 'unknown';
      final model = (result['model'] as String?) ?? 'unknown';
      final osVersion = result['osVersion'] as String?;
      final capabilityNames =
          (result['capabilities'] as List?)?.cast<String>() ?? const [];

      return DeviceInfo(
        manufacturer: manufacturer,
        model: model,
        osVersion: osVersion,
        capabilities: capabilityNames.map(_parseCapability).whereType<HardwareCapability>().toSet(),
      );
    } on MissingPluginException {
      return _fallback();
    } on PlatformException {
      return _fallback();
    }
  }

  DeviceInfo _fallback() => const DeviceInfo(
        manufacturer: 'unknown',
        model: 'unknown',
        capabilities: {HardwareCapability.camera},
      );

  HardwareCapability? _parseCapability(String raw) {
    switch (raw) {
      case 'camera':
        return HardwareCapability.camera;
      case 'builtInBarcodeScanner':
        return HardwareCapability.builtInBarcodeScanner;
      case 'builtInRfidReader':
        return HardwareCapability.builtInRfidReader;
      case 'bluetoothRfidReader':
        return HardwareCapability.bluetoothRfidReader;
      case 'usbRfidReader':
        return HardwareCapability.usbRfidReader;
    }
    return null;
  }
}
