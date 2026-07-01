import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/hr_api_client.dart';
import '../../../core/storage/secure_session_store.dart';
import '../data/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(
    ref.watch(hrApiClientProvider),
    ref.watch(secureSessionStoreProvider),
  );
});

final expenseClaimsProvider = FutureProvider((ref) {
  return ref.watch(expenseRepositoryProvider).list();
});

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(expenseClaimsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _ExpenseDialog(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Claim'),
      ),
      body: claims.when(
        data: (rows) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (_, index) {
            final row = rows[index];
            return ListTile(
              title: Text(row.name),
              subtitle: Text(row.status),
              trailing: Text(row.totalClaimedAmount.toString()),
            );
          },
        ),
        error: (_, __) => const Center(child: Text('Unable to load expenses.')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ExpenseDialog extends ConsumerStatefulWidget {
  const _ExpenseDialog();

  @override
  ConsumerState<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends ConsumerState<_ExpenseDialog> {
  final _type = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _type.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Submit expense'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _type, decoration: const InputDecoration(labelText: 'Expense type')),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            await ref.read(expenseRepositoryProvider).submit(
                  type: _type.text,
                  amount: num.tryParse(_amount.text) ?? 0,
                );
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
