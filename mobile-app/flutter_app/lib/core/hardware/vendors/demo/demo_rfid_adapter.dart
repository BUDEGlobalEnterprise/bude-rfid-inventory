import 'dart:async';

import '../../adapters/hardware_exceptions.dart';
import '../../adapters/rfid_adapter.dart';
import '../../entities/rfid_tag.dart';

/// Development/demo RFID reader used when no physical reader is available.
///
/// It implements the same HAL contract as a real UHF reader so lookup and
/// future batch inventory flows can be exercised without vendor hardware.
class DemoRfidAdapter implements RfidAdapter {
  DemoRfidAdapter({
    List<String>? epcs,
    this.inventoryInterval = const Duration(milliseconds: 500),
  }) : _epcs = epcs ?? defaultEpcs;

  static const defaultEpcs = <String>[
    'E2000017221101441890ABCD',
    'E2000017221101441890ABCE',
    'E2000017221101441890ABCF',
  ];

  final List<String> _epcs;
  final Duration inventoryInterval;
  final _controller = StreamController<RfidTag>.broadcast();

  bool _connected = false;
  bool _disposed = false;
  int _nextIndex = 0;
  int _powerLevel = 20;
  Timer? _timer;

  @override
  String get vendor => 'demo';

  @override
  bool get isConnected => _connected && !_disposed;

  @override
  Stream<RfidTag> get tagStream => _controller.stream;

  @override
  Future<void> connect() async {
    _ensureUsable();
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    await stopInventory();
    _connected = false;
  }

  @override
  Future<void> startInventory() async {
    _ensureConnected();
    if (_timer != null) return;
    _timer = Timer.periodic(inventoryInterval, (_) {
      if (!_controller.isClosed) {
        _controller.add(_nextTag());
      }
    });
    _controller.add(_nextTag());
  }

  @override
  Future<void> stopInventory() async {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<RfidTag?> readTag({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _ensureConnected();
    return _nextTag();
  }

  @override
  Future<void> writeTagEpc(String newEpc, {String? accessPassword}) async {
    throw const HardwareOperationException(
      'Demo RFID reader does not support writing EPCs.',
    );
  }

  @override
  Future<void> lockTag({
    required RfidMemoryBank bank,
    required String accessPassword,
  }) async {
    throw const HardwareOperationException(
      'Demo RFID reader does not support locking tags.',
    );
  }

  @override
  Future<void> killTag({required String killPassword}) async {
    throw const HardwareOperationException(
      'Demo RFID reader does not support killing tags.',
    );
  }

  @override
  Future<void> setPowerLevel(int dbm) async {
    _ensureUsable();
    if (dbm < 5 || dbm > 30) {
      throw const HardwareOperationException(
        'Demo RFID power level must be between 5 and 30 dBm.',
      );
    }
    _powerLevel = dbm;
  }

  @override
  Future<int> getPowerLevel() async {
    _ensureUsable();
    return _powerLevel;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    _disposed = true;
    await _controller.close();
  }

  RfidTag _nextTag() {
    final epc = _epcs[_nextIndex % _epcs.length];
    _nextIndex++;
    return RfidTag(
      epc: epc,
      tid: 'DEMO-TID-${_nextIndex.toString().padLeft(4, '0')}',
      rssi: -42 - (_nextIndex % 8),
      antenna: 1,
    );
  }

  void _ensureConnected() {
    _ensureUsable();
    if (!_connected) {
      throw const HardwareNotConnectedException(
        'Demo RFID reader is not connected.',
      );
    }
  }

  void _ensureUsable() {
    if (_disposed) {
      throw const HardwareOperationException(
        'Demo RFID reader has been disposed.',
      );
    }
    if (_epcs.isEmpty) {
      throw const HardwareOperationException(
        'Demo RFID reader has no EPCs configured.',
      );
    }
  }
}
