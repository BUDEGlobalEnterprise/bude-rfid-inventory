import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/hr_api_client.dart';
import '../../../core/offline/pending_operations_queue.dart';
import '../../../core/storage/secure_session_store.dart';
import '../../../core/widgets/dialogs.dart';
import '../data/expense_repository.dart';
import 'expense_detail_screen.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(
    ref.watch(hrApiClientProvider),
    ref.watch(secureSessionStoreProvider),
    ref.watch(pendingOperationsQueueProvider),
  );
});

final expenseClaimsProvider = FutureProvider((ref) {
  return ref.watch(expenseRepositoryProvider).list();
});

final expenseTypesProvider = FutureProvider((ref) {
  return ref.watch(expenseRepositoryProvider).types();
});

final pendingExpenseDraftsProvider = FutureProvider((ref) {
  return ref.watch(expenseRepositoryProvider).pendingDrafts();
});

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(expenseClaimsProvider);
    final drafts = ref.watch(pendingExpenseDraftsProvider);
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
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(expenseClaimsProvider);
          ref.invalidate(pendingExpenseDraftsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            drafts.maybeWhen(
              data: (rows) => rows.isEmpty
                  ? const SizedBox.shrink()
                  : _PendingDraftsCard(count: rows.length),
              orElse: () => const SizedBox.shrink(),
            ),
            claims.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(child: Text('No expense claims yet.')),
                  );
                }
                return Column(
                  children: [
                    for (final row in rows)
                      Card(
                        child: ListTile(
                          title: Text(row.name),
                          subtitle: Text(row.status),
                          trailing: Text(row.totalClaimedAmount.toString()),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ExpenseDetailScreen(name: row.name),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
              error: (_, __) => Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(
                  child: Column(
                    children: [
                      const Text('Unable to load expenses.'),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(expenseClaimsProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingDraftsCard extends ConsumerWidget {
  const _PendingDraftsCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$count expense draft(s) waiting to sync'),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await ref.read(expenseRepositoryProvider).retryDrafts();
                    ref.invalidate(pendingExpenseDraftsProvider);
                    ref.invalidate(expenseClaimsProvider);
                  },
                  icon: const Icon(Icons.sync),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _confirmDiscard(context, ref),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Discard'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Discard drafts?',
      message: 'Expense drafts waiting to sync will be permanently removed.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (confirmed) {
      await ref.read(expenseRepositoryProvider).discardDrafts();
      ref.invalidate(pendingExpenseDraftsProvider);
    }
  }
}

class _ExpenseDialog extends ConsumerStatefulWidget {
  const _ExpenseDialog();

  @override
  ConsumerState<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends ConsumerState<_ExpenseDialog> {
  String? _type;
  DateTime? _date;
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_type == null || _type!.isEmpty) return 'Select an expense type.';
    final amount = num.tryParse(_amount.text);
    if (amount == null || amount <= 0) return 'Enter an amount greater than 0.';
    return null;
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    await ref.read(expenseRepositoryProvider).submit(
          type: _type!,
          amount: num.parse(_amount.text),
          description: _description.text.isEmpty ? null : _description.text,
          postingDate: _date == null ? null : _formatDate(_date!),
        );
    ref.invalidate(expenseClaimsProvider);
    ref.invalidate(pendingExpenseDraftsProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(expenseTypesProvider).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <String>[],
        );
    return AlertDialog(
      title: const Text('Submit expense'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Expense type'),
            items: [
              for (final type in types)
                DropdownMenuItem(value: type, child: Text(type)),
            ],
            onChanged: (value) => setState(() => _type = value),
          ),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              _date == null ? 'Expense date' : 'Expense date: ${_formatDate(_date!)}',
            ),
          ),
          TextField(
            controller: _description,
            decoration:
                const InputDecoration(labelText: 'Description (optional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Submit'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
