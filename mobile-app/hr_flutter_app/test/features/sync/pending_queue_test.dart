import 'package:bude_hr/core/network/hr_api_client.dart';
import 'package:bude_hr/core/offline/pending_operation.dart';
import 'package:bude_hr/core/offline/pending_operations_queue.dart';
import 'package:bude_hr/core/storage/secure_session_store.dart';
import 'package:bude_hr/features/attendance/data/attendance_repository.dart';
import 'package:bude_hr/features/expenses/data/expense_repository.dart';
import 'package:bude_hr/features/sync/presentation/pending_queue_screen.dart';
import 'package:bude_hr/features/sync/presentation/sync_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _session = HrSession(
  baseUrl: 'https://erp.example.com',
  user: 'employee@example.com',
  fullName: 'Test Employee',
  apiKey: 'key',
  apiSecret: 'secret',
  roles: ['Employee'],
);

PendingHrOperation _attendanceOp(String id) => PendingHrOperation(
      id: id,
      type: PendingOperationType.attendanceCheckIn,
      payload: const {'type': 'IN'},
      createdAt: DateTime.parse('2026-07-01T09:00:00'),
    );

PendingHrOperation _expenseOp(String id) => PendingHrOperation(
      id: id,
      type: PendingOperationType.expenseDraft,
      payload: const {'expense_type': 'Travel', 'amount': 50},
      createdAt: DateTime.parse('2026-07-01T10:00:00'),
    );

SyncController _controller(PendingOperationsQueue queue, {required bool ok}) {
  final client = _RespondingApiClient(ok: ok);
  final store = _FixedSessionStore(_session);
  return SyncController(
    queue,
    AttendanceRepository(client, store, queue),
    ExpenseRepository(client, store, queue),
  );
}

void main() {
  test('syncAll clears operations from both features when they sync',
      () async {
    SharedPreferences.setMockInitialValues({});
    final queue = PendingOperationsQueue();
    await queue.enqueue(_attendanceOp('a-1'));
    await queue.enqueue(_expenseOp('e-1'));
    final controller = _controller(queue, ok: true);
    await controller.load();
    expect(controller.state.operations, hasLength(2));

    await controller.syncAll();

    expect(controller.state.operations, isEmpty);
    expect(controller.state.lastError, isNull);
  });

  test('syncAll keeps operations and reports an error when sync fails',
      () async {
    SharedPreferences.setMockInitialValues({});
    final queue = PendingOperationsQueue();
    await queue.enqueue(_attendanceOp('a-1'));
    final controller = _controller(queue, ok: false);

    await controller.syncAll();

    expect(controller.state.operations, hasLength(1));
    expect(controller.state.lastError, isNotNull);
  });

  test('discard removes a single operation', () async {
    SharedPreferences.setMockInitialValues({});
    final queue = PendingOperationsQueue();
    await queue.enqueue(_attendanceOp('a-1'));
    await queue.enqueue(_expenseOp('e-1'));
    final controller = _controller(queue, ok: true);
    await controller.load();

    await controller.discard('a-1');

    expect(controller.state.operations, hasLength(1));
    expect(controller.state.operations.single.id, 'e-1');
  });

  testWidgets('pending queue screen lists queued operations', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final queue = PendingOperationsQueue();
    await queue.enqueue(_expenseOp('e-1'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncControllerProvider.overrideWith(
            (ref) => _controller(queue, ok: false)..load(),
          ),
        ],
        child: const MaterialApp(home: PendingQueueScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Expense'), findsWidgets);
  });
}

class _FixedSessionStore extends SecureSessionStore {
  _FixedSessionStore(this._session);

  final HrSession _session;

  @override
  Future<HrSession?> read() async => _session;

  @override
  Future<void> write(HrSession session) async {}

  @override
  Future<void> clear() async {}
}

class _RespondingApiClient extends HrApiClient {
  _RespondingApiClient({required this.ok})
      : super(_FixedSessionStore(_session));

  final bool ok;

  @override
  Future<Map<String, dynamic>> post(
    String baseUrl,
    String path, {
    Map<String, dynamic>? data,
  }) async {
    return ok ? {'ok': true} : {'ok': false, 'message': 'Server error.'};
  }
}
