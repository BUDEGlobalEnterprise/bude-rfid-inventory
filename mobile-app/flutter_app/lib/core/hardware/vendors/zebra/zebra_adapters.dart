import '../_stub_barcode_adapter.dart';
import '../_stub_rfid_adapter.dart';

class ZebraBarcodeAdapter extends StubBarcodeAdapter {
  @override
  String get vendor => 'zebra';

  @override
  String get installHint =>
      'Add Zebra DataWedge or EMDK to the Android project, then implement '
      'BarcodeAdapter directly under lib/core/hardware/vendors/zebra/.';
}

class ZebraRfidAdapter extends StubRfidAdapter {
  @override
  String get vendor => 'zebra';

  @override
  String get installHint =>
      'Add Zebra RFID SDK for Android (com.zebra.rfid.api3) to '
      'android/app/libs/, then implement RfidAdapter directly under '
      'lib/core/hardware/vendors/zebra/.';
}
