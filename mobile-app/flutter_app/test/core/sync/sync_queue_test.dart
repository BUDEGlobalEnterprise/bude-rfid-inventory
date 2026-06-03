import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/core/sync/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_box.dart';

void main() {
  late FakeBox box;
  late SyncQueue queue;

  setUp(() {
    box = FakeBox();
    queue = SyncQueue(box: box);
  });

  tearDown(() => queue.dispose());

  test('enqueue persists op with pending status and returns id', () async {
    final id = await queue.enqueue(
      type: 'stock_transfer',
      payload: {'qty': 5},
    );

    expect(id, isNotEmpty);
    final stored = queue.getById(id)!;
    expect(stored.type, 'stock_transfer');
    expect(stored.payload['qty'], 5);
    expect(stored.status, OpStatus.pending);
    expect(stored.attempts, 0);
  });

  test('unresolvedCount excludes succeeded ops', () async {
    final id1 = await queue.enqueue(type: 't', payload: {});
    final id2 = await queue.enqueue(type: 't', payload: {});
    await queue.enqueue(type: 't', payload: {});

    expect(queue.unresolvedCount(), 3);

    await queue.update(
      queue.getById(id1)!.copyWith(status: OpStatus.succeeded),
    );
    await queue.update(
      queue.getById(id2)!.copyWith(status: OpStatus.failed),
    );

    expect(queue.unresolvedCount(), 2);
  });

  test('nextEligible returns oldest pending op without backoff', () async {
    await queue.enqueue(type: 't', payload: {'n': 1});
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await queue.enqueue(type: 't', payload: {'n': 2});

    final next = queue.nextEligible();
    expect(next!.payload['n'], 1);
  });

  test('nextEligible skips ops whose nextRetryAt is in the future', () async {
    final id = await queue.enqueue(type: 't', payload: {});
    final future = DateTime.now().toUtc().add(const Duration(minutes: 5));
    await queue.update(
      queue.getById(id)!.copyWith(nextRetryAt: future),
    );

    expect(queue.nextEligible(), isNull);

    final past = DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 10)); // probe time after backoff
    expect(queue.nextEligible(now: past)?.id, id);
  });

  test('retry resets a failed op and clears error + backoff', () async {
    final id = await queue.enqueue(type: 't', payload: {});
    await queue.update(
      queue.getById(id)!.copyWith(
        status: OpStatus.failed,
        attempts: 3,
        lastError: 'boom',
        nextRetryAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
      ),
    );

    await queue.retry(id);

    final after = queue.getById(id)!;
    expect(after.status, OpStatus.pending);
    expect(after.attempts, 0);
    expect(after.lastError, isNull);
    expect(after.nextRetryAt, isNull);
  });

  test('unresolvedCountStream emits on enqueue/update/delete', () async {
    final events = <int>[];
    final sub = queue.unresolvedCountStream().listen(events.add);

    final id = await queue.enqueue(type: 't', payload: {});
    await Future<void>.delayed(Duration.zero);
    await queue.update(
      queue.getById(id)!.copyWith(status: OpStatus.succeeded),
    );
    await Future<void>.delayed(Duration.zero);
    await queue.delete(id);
    await Future<void>.delayed(Duration.zero);

    await sub.cancel();
    expect(events, [0, 1, 0, 0]);
  });
}

