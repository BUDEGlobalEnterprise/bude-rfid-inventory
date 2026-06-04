import '../_stub_barcode_adapter.dart';

/// Honeywell handhelds typically expose barcode but not UHF RFID — only the
/// barcode adapter ships here.
class HoneywellBarcodeAdapter extends StubBarcodeAdapter {
  @override
  String get vendor => 'honeywell';

  @override
  String get installHint =>
      'Add Honeywell DataCollection SDK (com.honeywell.aidc) to '
      'android/app/libs/, then implement BarcodeAdapter directly under '
      'lib/core/hardware/vendors/honeywell/.';
}
