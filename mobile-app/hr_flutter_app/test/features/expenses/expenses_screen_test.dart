import 'package:bude_hr/core/network/hr_api_client.dart';
import 'package:bude_hr/core/offline/pending_operation.dart';
import 'package:bude_hr/core/offline/pending_operations_queue.dart';
import 'package:bude_hr/core/storage/secure_session_store.dart';
import 'package:bude_hr/features/expenses/data/expense_repository.dart';
import 'package:bude_hr/features/expenses/presentation/expenses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('blocks submitting an expense without a type', (tester) async {
    final store = _FakeSessionStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureSessionStoreProvider.overrideWithValue(store),
          expenseRepositoryProvider.overrideWithValue(
            _FakeExpenseRepository(store),
          ),
        ],
        child: const MaterialApp(home: ExpensesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Claim'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.text('Select an expense type.'), findsOneWidget);
  });
}

class _FakeExpenseRepository extends ExpenseRepository {
  _FakeExpenseRepository(SecureSessionStore store)
      : super(HrApiClient(store), store, PendingOperationsQueue());

  @override
  Future<List<ExpenseClaimSummary>> list() async => const [];

  @override
  Future<List<String>> types() async => const ['Travel', 'Food'];

  @override
  Future<List<PendingHrOperation>> pendingDrafts() async => const [];
}

class _FakeSessionStore extends SecureSessionStore {
  @override
  Future<HrSession?> read() async => null;

  @override
  Future<void> write(HrSession session) async {}

  @override
  Future<void> clear() async {}
}
