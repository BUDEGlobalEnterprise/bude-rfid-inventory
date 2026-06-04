import '../entities/scan_event.dart';

/// Contract for any barcode-producing hardware — camera, integrated scanner,
/// Bluetooth scanner, USB scanner. Business code (inventory, transfer, etc.)
/// only ever talks to this interface.
///
/// Implementations live in `lib/core/hardware/vendors/` and `camera/`. New
/// vendors plug in by registering via [HardwareRegistry] at app start; no
/// changes to business modules are required.
abstract class BarcodeAdapter {
  /// Stable vendor identifier, e.g. "camera", "chainway", "zebra".
  String get vendor;

  /// Stream of decoded barcodes while a scan is active. Emits as long as the
  /// adapter is "scanning" (between [startScan] and [stopScan]).
  Stream<ScanEvent> get events;

  /// Start producing scan events. For continuous-scan hardware this begins
  /// the inventory loop; for camera-style adapters it opens the preview.
  Future<void> startScan();
  Future<void> stopScan();

  /// One-shot helper: starts scanning, awaits the first event, stops.
  /// Returns null if no scan happened before [timeout].
  Future<ScanEvent?> scanSingle({Duration timeout = const Duration(seconds: 30)});

  /// True when continuous-mode scanning is supported in hardware. Some
  /// vendors (e.g. camera) emulate continuous mode in software.
  bool get supportsContinuousScan;

  /// Release native resources. After this, the adapter must not be used again.
  Future<void> dispose();
}
