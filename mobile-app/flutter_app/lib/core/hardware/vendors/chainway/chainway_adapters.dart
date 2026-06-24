import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../adapters/barcode_adapter.dart';
import '../../adapters/hardware_exceptions.dart';
import '../../adapters/rfid_adapter.dart';
import '../../entities/rfid_tag.dart';
import '../../entities/scan_event.dart';

const _chainwayInstallHint =
    'Bundle Chainway DeviceAPI_ver20251103_release.aar in '
    'android/app/libs/ and register ChainwayHardwarePlugin on Android.';

/// Chainway barcode adapter backed by the native Chainway Android SDK.
class ChainwayBarcodeAdapter implements BarcodeAdapter {
  static const _methods = MethodChannel('bude.hardware/chainway/barcode');
  static const _events = EventChannel('bude.hardware/chainway/barcode/events');

  Stream<ScanEvent>? _eventStream;

  @override
  String get vendor => 'chainway';

  @override
  Stream<ScanEvent> get events => _eventStream ??= _events
      .receiveBroadcastStream()
      .map((event) => _scanEventFromMap(_asStringMap(event)));

  @override
  bool get supportsContinuousScan => true;

  @override
  Future<void> startScan() async {
    await _invokeCommand(() => _methods.invokeMethod<bool>('startScan'));
  }

  @override
  Future<void> stopScan() async {
    await _invokeCommand(() => _methods.invokeMethod<bool>('stopScan'));
  }

  @override
  Future<ScanEvent?> scanSingle({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final result = await _invoke(
      () => _methods.invokeMapMethod<String, Object?>(
        'scanSingle',
        {'timeoutMillis': timeout.inMilliseconds},
      ),
    );
    return result == null ? null : _scanEventFromMap(result);
  }

  @override
  Future<void> dispose() async {
    try {
      await _invokeCommand(() => _methods.invokeMethod<bool>('dispose'));
    } on VendorSdkUnavailableException {
      // Disposal should stay idempotent in host tests and non-Android builds.
    }
  }
}

/// Chainway UHF RFID adapter backed by the native Chainway Android SDK.
class ChainwayRfidAdapter implements RfidAdapter {
  static const _methods = MethodChannel('bude.hardware/chainway/rfid');
  static const _events = EventChannel('bude.hardware/chainway/rfid/events');

  Stream<RfidTag>? _tagStream;
  bool _isConnected = false;

  @override
  String get vendor => 'chainway';

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<RfidTag> get tagStream => _tagStream ??= _events
      .receiveBroadcastStream()
      .map((event) => _rfidTagFromMap(_asStringMap(event)));

  @override
  Future<void> connect() async {
    final connected = await _invoke(
      () => _methods.invokeMethod<bool>('connect'),
    );
    _isConnected = connected ?? false;
    if (!_isConnected) {
      throw const HardwareNotConnectedException(
        'Chainway UHF reader failed to initialize.',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    await _invokeCommand(() => _methods.invokeMethod<bool>('disconnect'));
    _isConnected = false;
  }

  @override
  Future<void> startInventory() async {
    await _invokeCommand(() => _methods.invokeMethod<bool>('startInventory'));
    _isConnected = true;
  }

  @override
  Future<void> stopInventory() async {
    await _invokeCommand(() => _methods.invokeMethod<bool>('stopInventory'));
  }

  @override
  Future<RfidTag?> readTag({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final result = await _invoke(
      () => _methods.invokeMapMethod<String, Object?>(
        'readTag',
        {'timeoutMillis': timeout.inMilliseconds},
      ),
    );
    return result == null ? null : _rfidTagFromMap(result);
  }

  @override
  Future<void> writeTagEpc(String newEpc, {String? accessPassword}) async {
    await _invokeCommand(
      () => _methods.invokeMethod<bool>(
        'writeTagEpc',
        {
          'epc': newEpc,
          if (accessPassword != null) 'accessPassword': accessPassword,
        },
      ),
    );
  }

  @override
  Future<void> lockTag({
    required RfidMemoryBank bank,
    required String accessPassword,
  }) async {
    await _invokeCommand(
      () => _methods.invokeMethod<bool>(
        'lockTag',
        {'bank': bank.name, 'accessPassword': accessPassword},
      ),
    );
  }

  @override
  Future<void> killTag({required String killPassword}) async {
    await _invokeCommand(
      () => _methods.invokeMethod<bool>(
        'killTag',
        {'killPassword': killPassword},
      ),
    );
  }

  @override
  Future<void> setPowerLevel(int dbm) async {
    await _invokeCommand(
      () => _methods.invokeMethod<bool>('setPowerLevel', {'dbm': dbm}),
    );
  }

  @override
  Future<int> getPowerLevel() async {
    return await _invoke(() => _methods.invokeMethod<int>('getPowerLevel')) ??
        0;
  }

  @override
  Future<void> dispose() async {
    try {
      await _invokeCommand(() => _methods.invokeMethod<bool>('dispose'));
    } on VendorSdkUnavailableException {
      // Disposal should stay idempotent in host tests and non-Android builds.
    }
    _isConnected = false;
  }
}

Future<void> _invokeCommand(Future<bool?> Function() operation) async {
  final ok = await _invoke(operation);
  if (ok == false) {
    throw const HardwareOperationException('Chainway SDK operation failed.');
  }
}

Future<T?> _invoke<T>(Future<T?> Function() operation) async {
  try {
    return await operation();
  } on MissingPluginException catch (_) {
    throw const VendorSdkUnavailableException(
      'chainway',
      _chainwayInstallHint,
    );
  } on PlatformException catch (error) {
    final message = error.message ?? error.code;
    if (error.code == 'MissingPluginException') {
      throw const VendorSdkUnavailableException(
        'chainway',
        _chainwayInstallHint,
      );
    }
    throw HardwareOperationException(message);
  } on FlutterError catch (error) {
    final message = error.message;
    if (message.contains('Binding has not yet been initialized')) {
      throw const VendorSdkUnavailableException(
        'chainway',
        _chainwayInstallHint,
      );
    }
    throw HardwareOperationException(message);
  }
}

Map<String, Object?> _asStringMap(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  throw const HardwareOperationException('Unexpected Chainway event payload.');
}

ScanEvent _scanEventFromMap(Map<String, Object?> map) {
  return ScanEvent(
    barcode: map['barcode']?.toString() ?? '',
    format: map['format']?.toString(),
    timestamp: _timestampFromMap(map),
  );
}

RfidTag _rfidTagFromMap(Map<String, Object?> map) {
  return RfidTag(
    epc: map['epc']?.toString() ?? '',
    tid: map['tid']?.toString(),
    userMemory: map['userMemory']?.toString(),
    rssi: _intFromMap(map['rssi']),
    antenna: _intFromMap(map['antenna']),
    timestamp: _timestampFromMap(map),
  );
}

DateTime _timestampFromMap(Map<String, Object?> map) {
  final millis = _intFromMap(map['timestampMillis']);
  return millis == null
      ? DateTime.now()
      : DateTime.fromMillisecondsSinceEpoch(millis);
}

int? _intFromMap(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
