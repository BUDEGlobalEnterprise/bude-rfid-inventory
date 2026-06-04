import '../_stub_barcode_adapter.dart';
import '../_stub_rfid_adapter.dart';

class UrovoBarcodeAdapter extends StubBarcodeAdapter {
  @override
  String get vendor => 'urovo';

  @override
  String get installHint =>
      'Add Urovo Android SDK (com.android.scanner.service) to '
      'android/app/libs/, then implement BarcodeAdapter directly under '
      'lib/core/hardware/vendors/urovo/.';
}

class UrovoRfidAdapter extends StubRfidAdapter {
  @override
  String get vendor => 'urovo';

  @override
  String get installHint =>
      'Add Urovo UHF SDK to android/app/libs/, then implement RfidAdapter '
      'directly under lib/core/hardware/vendors/urovo/.';
}
