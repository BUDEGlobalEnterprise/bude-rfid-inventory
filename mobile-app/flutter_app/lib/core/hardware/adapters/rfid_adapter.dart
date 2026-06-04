import '../entities/rfid_tag.dart';

/// Contract for any RFID/UHF reader — handheld, Bluetooth sled, USB,
/// fixed gate. Business code calls these methods without knowing the vendor.
///
/// Most operations are async because RFID hardware typically talks over a
/// serial / BLE / USB link with its own latency profile.
abstract class RfidAdapter {
  /// Stable vendor identifier, e.g. "chainway", "zebra", "urovo", "generic".
  String get vendor;

  /// Open the connection to the underlying reader (BLE pair, USB enumerate,
  /// integrated SDK init, etc.). Idempotent — calling twice is safe.
  Future<void> connect();
  Future<void> disconnect();
  bool get isConnected;

  /// Tag stream emitted while an inventory pass is running.
  Stream<RfidTag> get tagStream;

  /// Begin a continuous inventory pass — driver keeps reading until stopped.
  Future<void> startInventory();
  Future<void> stopInventory();

  /// Single tag read — useful for "tap to identify" UX.
  Future<RfidTag?> readTag({Duration timeout = const Duration(seconds: 5)});

  /// Write the EPC of the currently-targeted tag.
  Future<void> writeTagEpc(String newEpc, {String? accessPassword});

  /// Lock a memory bank on the tag. [bank] is a vendor-neutral enum value.
  Future<void> lockTag({
    required RfidMemoryBank bank,
    required String accessPassword,
  });

  /// Permanently kill a tag (renders it unreadable). Requires the kill
  /// password; some firmwares refuse this entirely.
  Future<void> killTag({required String killPassword});

  /// Power level in dBm. Range and granularity are vendor-specific; consult
  /// the adapter docs. Throws [HardwareOperationException] if out of range.
  Future<void> setPowerLevel(int dbm);
  Future<int> getPowerLevel();

  /// Release native resources.
  Future<void> dispose();
}

enum RfidMemoryBank { reserved, epc, tid, user }
