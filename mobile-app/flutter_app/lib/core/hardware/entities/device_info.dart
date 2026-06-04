import 'package:equatable/equatable.dart';

/// Identifying details about the host device or attached hardware. Populated
/// by a [DeviceProbe] at app start and consumed by [HardwareManager] for
/// adapter selection.
class DeviceInfo extends Equatable {
  /// e.g. "Chainway", "Zebra", "Urovo", "Honeywell", "unknown".
  final String manufacturer;

  /// e.g. "C72", "TC52", "RT40".
  final String model;

  /// Android Build.VERSION.RELEASE (e.g. "13") or null on other platforms.
  final String? osVersion;

  /// Detected hardware capabilities — which adapter types might serve.
  final Set<HardwareCapability> capabilities;

  const DeviceInfo({
    required this.manufacturer,
    required this.model,
    this.osVersion,
    this.capabilities = const {},
  });

  bool get isUnknownVendor => manufacturer.toLowerCase() == 'unknown';

  @override
  List<Object?> get props => [manufacturer, model, osVersion, capabilities];
}

enum HardwareCapability {
  camera,
  builtInBarcodeScanner,
  builtInRfidReader,
  bluetoothRfidReader,
  usbRfidReader,
}

/// Battery + connection snapshot for the connected (or built-in) device.
class DeviceStatus extends Equatable {
  /// 0–100 or null if the adapter can't report it.
  final int? batteryPercent;
  final String? firmwareVersion;
  final bool connected;

  const DeviceStatus({
    this.batteryPercent,
    this.firmwareVersion,
    required this.connected,
  });

  @override
  List<Object?> get props => [batteryPercent, firmwareVersion, connected];
}
