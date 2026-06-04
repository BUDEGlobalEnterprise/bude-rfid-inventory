import '../_stub_barcode_adapter.dart';
import '../_stub_rfid_adapter.dart';

/// Chainway barcode stub. Covers all Chainway handhelds (C72, C66, C61, etc.).
/// Real integration: add the Chainway Android SDK as an Android library and
/// implement BarcodeAdapter directly with a method-channel bridge.
class ChainwayBarcodeAdapter extends StubBarcodeAdapter {
  @override
  String get vendor => 'chainway';

  @override
  String get installHint =>
      'Add Chainway Android SDK to android/app/libs/, then implement '
      'BarcodeAdapter directly (not via StubBarcodeAdapter) under '
      'lib/core/hardware/vendors/chainway/.';
}

class ChainwayRfidAdapter extends StubRfidAdapter {
  @override
  String get vendor => 'chainway';

  @override
  String get installHint =>
      'Add Chainway UHF SDK (com.rscja.deviceapi.RFIDWithUHF*) to '
      'android/app/libs/, then implement RfidAdapter directly under '
      'lib/core/hardware/vendors/chainway/.';
}
