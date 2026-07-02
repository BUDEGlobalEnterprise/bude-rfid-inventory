import 'package:bude_hr/core/offline/pending_operation.dart';
import 'package:bude_hr/core/offline/pending_operations_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  PendingHrOperation op(String id, PendingOperationType type) {
    return PendingHrOperation(
      id: id,
      type: type,
      payload: type == PendingOperationType.attendanceCheckIn
          ? {'type': 'IN'}
          : {'expense_type': 'Travel', 'amount': 50},
      createdAt: DateTime.parse('2026-07-01T09:00:00'),
    );
  }

  test('serializes and restores an operation without loss', () {
    final original = op('a-1', PendingOperationType.expenseDraft);

    final restored = PendingHrOperation.fromJson(original.toJson());

    expect(restored.id, 'a-1');
    expect(restored.type, PendingOperationType.expenseDraft);
    expect(restored.payload['expense_type'], 'Travel');
    expect(restored.createdAt, original.createdAt);
  });

  test('enqueue and read round-trips through storage', () async {
    SharedPreferences.setMockInitialValues({});
    final queue = PendingOperationsQueue();

    await queue.enqueue(op('a-1', PendingOperationType.attendanceCheckIn));
    await queue.enqueue(op('e-1', PendingOperationType.expenseDraft));

    expect(await queue.read(), hasLength(2));
  });

  test('readByType and clearType only touch the given type', () async {
    SharedPreferences.setMockInitialValues({});
    final queue = PendingOperationsQueue();
    await queue.enqueue(op('a-1', PendingOperationType.attendanceCheckIn));
    await queue.enqueue(op('e-1', PendingOperationType.expenseDraft));

    expect(
      await queue.readByType(PendingOperationType.attendanceCheckIn),
      hasLength(1),
    );

    await queue.clearType(PendingOperationType.attendanceCheckIn);

    final remaining = await queue.read();
    expect(remaining, hasLength(1));
    expect(remaining.single.type, PendingOperationType.expenseDraft);
  });

  test('discard removes only the matching operation', () async {
    SharedPreferences.setMockInitialValues({});
    final queue = PendingOperationsQueue();
    await queue.enqueue(op('a-1', PendingOperationType.attendanceCheckIn));
    await queue.enqueue(op('a-2', PendingOperationType.attendanceCheckIn));

    await queue.discard('a-1');

    final remaining = await queue.read();
    expect(remaining, hasLength(1));
    expect(remaining.single.id, 'a-2');
  });
}
