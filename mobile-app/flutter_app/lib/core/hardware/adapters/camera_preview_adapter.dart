import 'package:flutter/widgets.dart';

/// Mix-in for [BarcodeAdapter] implementations that can render a live
/// camera viewfinder. [ScanSessionScreen] checks `adapter is CameraPreviewAdapter`
/// before calling [buildPreview].
abstract class CameraPreviewAdapter {
  Widget buildPreview();
}
