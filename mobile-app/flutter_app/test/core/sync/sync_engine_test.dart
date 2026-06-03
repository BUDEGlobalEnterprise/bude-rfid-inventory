import 'package:bude_inventory/core/network/network_info_impl.dart';
import 'package:bude_inventory/core/sync/op_submitter.dart';
import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/core/sync/sync_engine.dart';
import 'package:bude_inventory/core/sync/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_box.dart';

class _MockNetworkInfo extends Mock implements NetworkInfoImpl {}

class _ConfigurableSubmitter implements OpSubmitter {
  @override
  final String type;
  final List<SubmitResult> results;
  final List<PendingOperation> received = [];
  int _idx = 0;

  _ConfigurableSubmitter({required this.type, required this.results});

  @override
  Future<SubmitResult> submit(PendingOperation op) async {
    received.add(op);
    return results[_idx++];
  }
}

void main() {
  late _MockNetworkInfo network;
  late SyncQueue queue;
  late FakeBox box;

  setUp(() {
    network = _MockNetworkInfo();
    box = FakeBox();
    queue = SyncQueue(box: box);

    when(() => network.onConnectivityChanged())
        .thenAnswer((_) => const Stream<bool>.empty());
  });

  tearDown(() => queue.dispose());

  test('kick does nothing when offline', () async {
    when(() => network.isConnected).thenAnswer((_) async => false);

    final submitter = _ConfigurableSubmitter(
      type: 'stock_transfer',
      results: const [SubmitSuccess('STE-001')],
    );
    final engine = SyncEngine(
      queue: queue,
      networkInfo: network,
      submitters: [submitter],
    );

    await queue.enqueue(type: 'stock_transfer', payload: {});
    await engine.kick();

    expect(submitter.received, isEmpty);
    expect(queue.pending(), hasLength(1));
  });

  test('successful submit marks op succeeded with serverRef', () async {
    when(() => network.isConnected).thenAnswer((_) async => true);

    final submitter = _ConfigurableSubmitter(
      type: 'stock_transfer',
      results: const [SubmitSuccess('STE-001')],
    );
    final engine = SyncEngine(
      queue: queue,
      networkInfo: network,
      submitters: [submitter],
    );

    final id = await queue.enqueue(type: 'stock_transfer', payload: {});
    await engine.kick();

    final after = queue.getById(id)!;
    expect(after.status, OpStatus.succeeded);
    expect(after.serverRef, 'STE-001');
    expect(after.lastError, isNull);
  });

  test('fatal failure marks op failed and does not retry', () async {
    when(() => network.isConnected).thenAnswer((_) async => true);

    final submitter = _ConfigurableSubmitter(
      type: 'stock_transfer',
      results: const [SubmitFatal('qty must be positive')],
    );
    final engine = SyncEngine(
      queue: queue,
      networkInfo: network,
      submitters: [submitter],
    );

    final id = await queue.enqueue(type: 'stock_transfer', payload: {});
    await engine.kick();

    final after = queue.getById(id)!;
    expect(after.status, OpStatus.failed);
    expect(after.lastError, 'qty must be positive');
    expect(after.attempts, 0);
  });

  test('retryable failure schedules backoff and increments attempts',
      () async {
    when(() => network.isConnected).thenAnswer((_) async => true);

    final submitter = _ConfigurableSubmitter(
      type: 'stock_transfer',
      results: const [SubmitRetryable('500 server error')],
    );
    final engine = SyncEngine(
      queue: queue,
      networkInfo: network,
      submitters: [submitter],
    );

    final id = await queue.enqueue(type: 'stock_transfer', payload: {});
    await engine.kick();

    final after = queue.getById(id)!;
    expect(after.status, OpStatus.pending);
    expect(after.attempts, 1);
    expect(after.lastError, '500 server error');
    expect(after.nextRetryAt, isNotNull);
    expect(after.nextRetryAt!.isAfter(DateTime.now().toUtc()), isTrue);
  });

  test('op with no matching submitter is marked failed', () async {
    when(() => network.isConnected).thenAnswer((_) async => true);

    final engine = SyncEngine(queue: queue, networkInfo: network);

    final id = await queue.enqueue(type: 'unknown_op', payload: {});
    await engine.kick();

    final after = queue.getById(id)!;
    expect(after.status, OpStatus.failed);
    expect(after.lastError, contains('unknown_op'));
  });

  test('submitter exception is treated as retryable', () async {
    when(() => network.isConnected).thenAnswer((_) async => true);

    final engine = SyncEngine(
      queue: queue,
      networkInfo: network,
      submitters: [_ThrowingSubmitter()],
    );

    final id = await queue.enqueue(type: 'stock_transfer', payload: {});
    await engine.kick();

    final after = queue.getById(id)!;
    expect(after.status, OpStatus.pending);
    expect(after.attempts, 1);
    expect(after.lastError, contains('boom'));
  });
}

class _ThrowingSubmitter implements OpSubmitter {
  @override
  String get type => 'stock_transfer';

  @override
  Future<SubmitResult> submit(PendingOperation op) async {
    throw StateError('boom');
  }
}
