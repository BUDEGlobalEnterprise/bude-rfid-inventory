import 'entities/device_info.dart';

/// Detects what host device the app is running on. The result drives
/// [HardwareManager]'s vendor selection — e.g. on a Chainway C72, pick the
/// Chainway adapters by default.
///
/// One implementation per platform. The default [DefaultDeviceProbe] returns
/// an "unknown" device, which causes [HardwareManager] to fall back to the
/// camera barcode adapter and no RFID adapter. Production builds wire in the
/// platform-specific probe (Android reads Build.MANUFACTURER/MODEL via a
/// method channel) before any business code runs.
abstract class DeviceProbe {
  Future<DeviceInfo> probe();
}

class DefaultDeviceProbe implements DeviceProbe {
  const DefaultDeviceProbe();

  @override
  Future<DeviceInfo> probe() async {
    return const DeviceInfo(
      manufacturer: 'unknown',
      model: 'unknown',
      capabilities: {HardwareCapability.camera},
    );
  }
}
