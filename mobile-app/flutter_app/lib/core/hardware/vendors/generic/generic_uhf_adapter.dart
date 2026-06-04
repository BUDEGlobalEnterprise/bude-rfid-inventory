import '../_stub_rfid_adapter.dart';

/// Catch-all stub for Bluetooth / USB / generic UHF readers that don't
/// match a known vendor. Real integration likely needs a per-protocol
/// driver (e.g. LLRP, BLE GATT profile).
class GenericUhfRfidAdapter extends StubRfidAdapter {
  @override
  String get vendor => 'generic';

  @override
  String get installHint =>
      'Generic UHF readers require a per-protocol driver. Implement '
      'RfidAdapter directly for the specific reader you intend to support '
      '(e.g. LLRP-over-TCP, BLE GATT) under lib/core/hardware/vendors/<name>/.';
}
