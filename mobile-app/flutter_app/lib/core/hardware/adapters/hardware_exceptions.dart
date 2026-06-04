/// Thrown when a vendor adapter is selected but its SDK isn't bundled in this
/// build. Stub adapters throw this with a clear message pointing at the
/// integration step the developer still needs to take.
class VendorSdkUnavailableException implements Exception {
  final String vendor;
  final String hint;
  const VendorSdkUnavailableException(this.vendor, this.hint);

  @override
  String toString() =>
      'VendorSdkUnavailableException: $vendor SDK not bundled. $hint';
}

/// Thrown when an adapter call would otherwise crash because the hardware is
/// not connected (e.g. trying to read a tag with no UHF reader attached).
class HardwareNotConnectedException implements Exception {
  final String message;
  const HardwareNotConnectedException(this.message);

  @override
  String toString() => 'HardwareNotConnectedException: $message';
}

/// Generic adapter failure with a human-readable message.
class HardwareOperationException implements Exception {
  final String message;
  const HardwareOperationException(this.message);

  @override
  String toString() => 'HardwareOperationException: $message';
}
