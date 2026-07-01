import 'package:bude_inventory/core/network/network_info_impl.dart';
import 'package:bude_inventory/core/sync/op_submitter.dart';
import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/core/sync/sync_engine.dart';
import 'package:bude_inventory/core/sync/sync_queue.dart';
import 'package:bude_inventory/features/assets/data/asset_op_submitters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_box.dart';

class _MockNetworkInfo extends Mock implements NetworkInfoImpl {}

class _SequencedSubmitter implements OpSubmitter {
  @override
  final String type;

  final List<SubmitResult> results;
  final List<PendingOperation> received = [];
  int _index = 0;

  _SequencedSubmitter(this.type, this.results);

  @override
  Future<SubmitResult> submit(PendingOperation op) async {
    received.add(op);
    return results[_index++];
  }
}

void main() {
  test('failed asset movement can be retried and then succeeds', () async {
    final queue = SyncQueue(box: FakeBox());
    final network = _MockNetworkInfo();
    final submitter = _SequencedSubmitter(kAssetMovementOpType, const [
      SubmitRetryable('temporary ERPNext outage'),
      SubmitSuccess('MOV-2026-00001'),
    ]);
    final engine = SyncEngine(
      queue: queue,
      networkInfo: network,
      submitters: [submitter],
    );

    when(() => network.isConnected).thenAnswer((_) async => true);
    when(() => network.onConnectivityChanged())
        .thenAnswer((_) => const Stream<bool>.empty());

    final id = await queue.enqueue(
      type: kAssetMovementOpType,
      payload: const {
        'assets': ['AST-001'],
        'purpose': 'Transfer',
        'target_location': 'Floor',
      },
    );

    await engine.kick();

    final failed = queue.getById(id)!;
    expect(failed.status, OpStatus.pending);
    expect(failed.attempts, 1);
    expect(failed.lastError, 'temporary ERPNext outage');
    expect(failed.nextRetryAt, isNotNull);

    await queue.retry(id);
    final retrying = queue.getById(id)!;
    expect(retrying.status, OpStatus.pending);
    expect(retrying.attempts, 0);

    await engine.kick();

    final succeeded = queue.getById(id)!;
    expect(succeeded.status, OpStatus.succeeded);
    expect(succeeded.serverRef, 'MOV-2026-00001');
    expect(submitter.received, hasLength(2));

    await queue.dispose();
  });

  test('asset repair op queued while offline survives until sync succeeds',
      () async {
    final queue = SyncQueue(box: FakeBox());
    final network = _MockNetworkInfo();
    final submitter = _SequencedSubmitter(kAssetRepairOpType, const [
      SubmitSuccess('ASSET-REPAIR-00001'),
    ]);
    final engine = SyncEngine(
      queue: queue,
      networkInfo: network,
      submitters: [submitter],
    );

    when(() => network.isConnected).thenAnswer((_) async => false);
    when(() => network.onConnectivityChanged())
        .thenAnswer((_) => const Stream<bool>.empty());

    final id = await queue.enqueue(
      type: kAssetRepairOpType,
      payload: const {'asset': 'AST-001', 'description': 'Motor noise'},
    );

    // Offline: kick() is a no-op, the draft persists untouched in the queue.
    await engine.kick();
    final stillQueued = queue.getById(id)!;
    expect(stillQueued.status, OpStatus.pending);
    expect(submitter.received, isEmpty);

    // Back online: the queued op is finally submitted.
    when(() => network.isConnected).thenAnswer((_) async => true);
    await engine.kick();

    final succeeded = queue.getById(id)!;
    expect(succeeded.status, OpStatus.succeeded);
    expect(succeeded.serverRef, 'ASSET-REPAIR-00001');

    await queue.dispose();
  });

  test('unsupported op type is marked failed instead of retried', () async {
    final queue = SyncQueue(box: FakeBox());
    final network = _MockNetworkInfo();
    final engine = SyncEngine(queue: queue, networkInfo: network);

    when(() => network.isConnected).thenAnswer((_) async => true);
    when(() => network.onConnectivityChanged())
        .thenAnswer((_) => const Stream<bool>.empty());

    final id = await queue.enqueue(
      type: kMaintenanceLogOpType,
      payload: const {'log': 'LOG-001'},
    );

    await engine.kick();

    final result = queue.getById(id)!;
    expect(result.status, OpStatus.failed);
    expect(result.lastError, contains('Unsupported op type'));

    await queue.dispose();
  });
}
