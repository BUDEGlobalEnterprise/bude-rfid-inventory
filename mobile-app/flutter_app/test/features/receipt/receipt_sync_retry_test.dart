import 'package:bude_inventory/core/network/network_info_impl.dart';
import 'package:bude_inventory/core/sync/op_submitter.dart';
import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/core/sync/sync_engine.dart';
import 'package:bude_inventory/core/sync/sync_queue.dart';
import 'package:bude_inventory/features/receipt/data/receipt_op_submitter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_box.dart';

class _MockNetworkInfo extends Mock implements NetworkInfoImpl {}

class _SequencedReceiptSubmitter implements OpSubmitter {
  @override
  String get type => kStockReceiptOpType;

  final List<SubmitResult> results;
  final List<PendingOperation> received = [];
  int _index = 0;

  _SequencedReceiptSubmitter(this.results);

  @override
  Future<SubmitResult> submit(PendingOperation op) async {
    received.add(op);
    return results[_index++];
  }
}

void main() {
  test('failed stock receipt can be retried and then succeeds', () async {
    final queue = SyncQueue(box: FakeBox());
    final network = _MockNetworkInfo();
    final submitter = _SequencedReceiptSubmitter(
      const [
        SubmitRetryable('temporary ERPNext outage'),
        SubmitSuccess('MAT-REC-2026-00042'),
      ],
    );
    final engine = SyncEngine(
      queue: queue,
      networkInfo: network,
      submitters: [submitter],
    );

    when(() => network.isConnected).thenAnswer((_) async => true);
    when(() => network.onConnectivityChanged())
        .thenAnswer((_) => const Stream<bool>.empty());

    final id = await queue.enqueue(
      type: kStockReceiptOpType,
      payload: const {
        'target_warehouse': 'Receiving - A',
        'items': [
          {'item_code': 'ITEM-A', 'qty': 1},
        ],
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
    expect(retrying.lastError, isNull);
    expect(retrying.nextRetryAt, isNull);

    await engine.kick();

    final succeeded = queue.getById(id)!;
    expect(succeeded.status, OpStatus.succeeded);
    expect(succeeded.serverRef, 'MAT-REC-2026-00042');
    expect(submitter.received, hasLength(2));

    await queue.dispose();
  });
}
