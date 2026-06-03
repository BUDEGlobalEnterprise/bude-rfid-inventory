import 'dart:async';

import 'package:mobile_scanner/mobile_scanner.dart';

import '../domain/scan_event.dart';
import '../domain/scanner.dart';

class CameraScanner implements Scanner {
  final MobileScannerController controller;
  final _controller = StreamController<ScanEvent>.broadcast();
  StreamSubscription<BarcodeCapture>? _sub;

  CameraScanner({MobileScannerController? controller})
      : controller = controller ??
            MobileScannerController(
              detectionSpeed: DetectionSpeed.normal,
              facing: CameraFacing.back,
            );

  @override
  Stream<ScanEvent> get events => _controller.stream;

  @override
  Future<void> start() async {
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
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await controller.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _controller.close();
    await controller.dispose();
  }
}
