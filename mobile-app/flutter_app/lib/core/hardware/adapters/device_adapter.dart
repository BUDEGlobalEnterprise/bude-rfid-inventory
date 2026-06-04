import '../entities/device_info.dart';

/// Device-info / power / firmware queries, independent of barcode + RFID
/// adapters. One implementation per host platform (Android, iOS, Windows)
/// rather than per vendor.
abstract class DeviceAdapter {
  Future<DeviceInfo> getDeviceInfo();
  Future<DeviceStatus> getDeviceStatus();
  Stream<DeviceStatus> watchDeviceStatus();
}
