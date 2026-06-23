import '../adapters/hardware_exceptions.dart';
import '../adapters/rfid_adapter.dart';
import '../entities/rfid_tag.dart';

/// Base class for vendor RFID adapters whose native SDK isn't bundled.
/// Every operation throws [VendorSdkUnavailableException] with a hint.
abstract class StubRfidAdapter implements RfidAdapter {
  String get installHint;

  Never _throw() => throw VendorSdkUnavailableException(vendor, installHint);

  @override
  bool get isConnected => false;

  @override
  Stream<RfidTag> get tagStream => _throw();

  @override
  Future<void> connect() async => _throw();

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> startInventory() async => _throw();

  @override
  Future<void> stopInventory() async => _throw();

  @override
  Future<RfidTag?> readTag({
    Duration timeout = const Duration(seconds: 5),
  }) async =>
      _throw();

  @override
  Future<void> writeTagEpc(String newEpc, {String? accessPassword}) async =>
      _throw();

  @override
  Future<void> lockTag({
    required RfidMemoryBank bank,
    required String accessPassword,
  }) async =>
      _throw();

  @override
  Future<void> killTag({required String killPassword}) async => _throw();

  @override
  Future<void> setPowerLevel(int dbm) async => _throw();

  @override
  Future<int> getPowerLevel() async => _throw();

  @override
  Future<void> dispose() async {}
}
