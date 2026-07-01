import 'package:bude_inventory/core/errors/exceptions.dart';
import 'package:bude_inventory/features/lookup/data/epc_remote_data_source.dart';
import 'package:bude_inventory/features/lookup/presentation/providers/lookup_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolve succeeds for an item match', () async {
    final dataSource = _FakeEpcDataSource()
      ..resolveResults.add(
        const ScanMatch(
          matchType: 'item',
          item: {'item_code': 'ITEM-001', 'item_name': 'Widget'},
        ),
      );
    final notifier = LookupNotifier(dataSource);

    await notifier.resolve(' ITEM-001 ');

    expect(
      notifier.state,
      isA<LookupResolved>()
          .having((s) => s.query, 'query', 'ITEM-001')
          .having((s) => s.match.matchType, 'match type', 'item')
          .having((s) => s.match.item?['item_code'], 'item code', 'ITEM-001'),
    );
    expect(dataSource.resolvedQueries, ['ITEM-001']);
  });

  test('resolve succeeds for asset and serial matches', () async {
    final dataSource = _FakeEpcDataSource()
      ..resolveResults.addAll([
        const ScanMatch(
          matchType: 'asset',
          asset: {'name': 'AST-001', 'asset_name': 'Forklift'},
        ),
        const ScanMatch(
          matchType: 'serial',
          serial: {'name': 'SN-001', 'item_code': 'ITEM-001'},
        ),
      ]);
    final notifier = LookupNotifier(dataSource);

    await notifier.resolve('EPC-ASSET');
    expect(
      notifier.state,
      isA<LookupResolved>().having(
        (s) => s.match.asset?['name'],
        'asset name',
        'AST-001',
      ),
    );

    await notifier.resolve('BARCODE-SERIAL');
    expect(
      notifier.state,
      isA<LookupResolved>().having(
        (s) => s.match.serial?['name'],
        'serial name',
        'SN-001',
      ),
    );
  });

  test('unknown EPC resolves as unregistered instead of error', () async {
    final dataSource = _FakeEpcDataSource()
      ..resolveResults.add(const ScanMatch());
    final notifier = LookupNotifier(dataSource);

    await notifier.resolve('UNKNOWN-EPC');

    expect(
      notifier.state,
      isA<LookupResolved>()
          .having((s) => s.query, 'query', 'UNKNOWN-EPC')
          .having((s) => s.match.isUnregistered, 'unregistered', isTrue),
    );
  });

  test('network error is marked offline and preserves query', () async {
    final dataSource = _FakeEpcDataSource()
      ..resolveResults.add(
        const NetworkException('Unable to connect.'),
      );
    final notifier = LookupNotifier(dataSource);

    await notifier.resolve('EPC-OFFLINE');

    expect(
      notifier.state,
      isA<LookupError>()
          .having((s) => s.query, 'query', 'EPC-OFFLINE')
          .having((s) => s.isOffline, 'is offline', isTrue)
          .having((s) => s.message, 'message', contains('Unable')),
    );
  });

  test('auth and server errors are surfaced without offline flag', () async {
    final dataSource = _FakeEpcDataSource()
      ..resolveResults.addAll([
        const AuthException('Authentication required.'),
        const ServerException('Request failed.'),
      ]);
    final notifier = LookupNotifier(dataSource);

    await notifier.resolve('EPC-AUTH');
    expect(
      notifier.state,
      isA<LookupError>()
          .having((s) => s.message, 'message', 'Authentication required.')
          .having((s) => s.isOffline, 'is offline', isFalse),
    );

    await notifier.resolve('EPC-SERVER');
    expect(
      notifier.state,
      isA<LookupError>()
          .having((s) => s.message, 'message', 'Request failed.')
          .having((s) => s.isOffline, 'is offline', isFalse),
    );
  });

  test('bind sends record identity and re-resolves the EPC', () async {
    final dataSource = _FakeEpcDataSource()
      ..resolveResults.add(
        const ScanMatch(
          matchType: 'asset',
          asset: {'name': 'AST-001'},
        ),
      );
    final notifier = LookupNotifier(dataSource);

    await notifier.bind('EPC-001', 'Asset', ' AST-001 ');

    expect(dataSource.bindCalls, [
      const _BindCall(doctype: 'Asset', name: 'AST-001', epc: 'EPC-001'),
    ]);
    expect(dataSource.resolvedQueries, ['EPC-001']);
    expect(
      notifier.state,
      isA<LookupResolved>().having(
        (s) => s.match.asset?['name'],
        'asset name',
        'AST-001',
      ),
    );
  });
}

class _FakeEpcDataSource extends EpcRemoteDataSource {
  final List<Object> resolveResults = [];
  final List<String> resolvedQueries = [];
  final List<_BindCall> bindCalls = [];

  _FakeEpcDataSource() : super(Dio());

  @override
  Future<ScanMatch> resolve(String epc) async {
    resolvedQueries.add(epc);
    final result = resolveResults.removeAt(0);
    if (result is Exception) throw result;
    return result as ScanMatch;
  }

  @override
  Future<void> bind(String doctype, String name, String epc) async {
    bindCalls.add(_BindCall(doctype: doctype, name: name, epc: epc));
  }
}

class _BindCall {
  final String doctype;
  final String name;
  final String epc;

  const _BindCall({
    required this.doctype,
    required this.name,
    required this.epc,
  });

  @override
  bool operator ==(Object other) =>
      other is _BindCall &&
      other.doctype == doctype &&
      other.name == name &&
      other.epc == epc;

  @override
  int get hashCode => Object.hash(doctype, name, epc);
}
