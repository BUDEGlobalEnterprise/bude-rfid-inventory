import '../adapters/barcode_adapter.dart';
import '../adapters/hardware_exceptions.dart';
import '../entities/scan_event.dart';

/// Base class for vendor barcode adapters whose native SDK isn't bundled in
/// this build. Every method throws [VendorSdkUnavailableException] with a
/// vendor-specific hint, so the user / developer gets a clear next step.
///
/// Replace this base when integrating the real SDK: drop a class that also
/// implements [BarcodeAdapter] under `vendors/<vendor>/` and update the
/// plugin's `barcodeFactory` in `vendors.dart` to point at the real impl.
abstract class StubBarcodeAdapter implements BarcodeAdapter {
  String get installHint;

  Never _throw() =>
      throw VendorSdkUnavailableException(vendor, installHint);

  @override
  Stream<ScanEvent> get events => _throw();

  @override
  bool get supportsContinuousScan => true;

  @override
  Future<void> startScan() async => _throw();

  @override
  Future<void> stopScan() async => _throw();

  @override
  Future<ScanEvent?> scanSingle({
    Duration timeout = const Duration(seconds: 30),
  }) async =>
      _throw();

  @override
  Future<void> dispose() async {}
}
