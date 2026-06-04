import 'dart:async';

import 'package:mobile_scanner/mobile_scanner.dart';

import '../adapters/barcode_adapter.dart';
import '../entities/scan_event.dart';

/// Camera-backed [BarcodeAdapter] using the `mobile_scanner` package.
/// Always available as a fallback when no vendor scanner is detected.
class CameraBarcodeAdapter implements BarcodeAdapter {
  @override
  final String vendor = 'camera';

  final MobileScannerController controller;
  final _controller = StreamController<ScanEvent>.broadcast();
  StreamSubscription<BarcodeCapture>? _sub;
  bool _running = false;

  CameraBarcodeAdapter({MobileScannerController? controller})
      : controller = controller ??
            MobileScannerController(
              detectionSpeed: DetectionSpeed.normal,
              facing: CameraFacing.back,
            );

  @override
  Stream<ScanEvent> get events => _controller.stream;

  @override
  bool get supportsContinuousScan => true;

  @override
  Future<void> startScan() async {
    if (_running) return;
    await controller.start();
    _sub ??= controller.barcodes.listen((capture) {
      for (final barcode in capture.barcodes) {
        final value = barcode.rawValue;
        if (value == null || value.isEmpty) continue;
        _controller.add(
          ScanEvent(barcode: value, format: barcode.format.name),
        );
      }
    });
    _running = true;
  }

  @override
  Future<void> stopScan() async {
    if (!_running) return;
    await _sub?.cancel();
    _sub = null;
    await controller.stop();
    _running = false;
  }

  @override
  Future<ScanEvent?> scanSingle({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await startScan();
    try {
      return await events.first.timeout(timeout, onTimeout: () => throw _Timeout());
    } on _Timeout {
      return null;
    } finally {
      await stopScan();
    }
  }

  @override
  Future<void> dispose() async {
    await stopScan();
    await _controller.close();
    await controller.dispose();
  }
}

class _Timeout implements Exception {}
