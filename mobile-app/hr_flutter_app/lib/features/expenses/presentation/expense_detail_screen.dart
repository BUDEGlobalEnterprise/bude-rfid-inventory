import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/expense_repository.dart';
import 'expenses_screen.dart';

final expenseDetailProvider =
    FutureProvider.family<ExpenseClaimDetail, String>((ref, name) {
  return ref.watch(expenseRepositoryProvider).detail(name);
});

class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(expenseDetailProvider(name));
    return Scaffold(
      appBar: AppBar(title: const Text('Expense claim')),
      body: detail.when(
        data: (claim) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(claim.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Posted ${claim.postingDate}'),
            const SizedBox(height: 20),
            _StatusTimeline(status: claim.status),
            const SizedBox(height: 20),
            Text('Amounts', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Claimed: ${claim.totalClaimedAmount}'),
            Text('Sanctioned: ${claim.totalSanctionedAmount}'),
            const SizedBox(height: 20),
            Text('Items', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final line in claim.expenses)
              Card(
                child: ListTile(
                  title: Text(line.expenseType),
                  subtitle:
                      line.description.isEmpty ? null : Text(line.description),
                  trailing: Text('${line.amount}'),
                ),
              ),
          ],
        ),
        error: (_, __) =>
            const Center(child: Text('Unable to load this expense claim.')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});

  final String status;

  static const _stages = ['Draft', 'Submitted', 'Approved', 'Paid'];

  int get _currentIndex {
    switch (status.toLowerCase()) {
      case 'paid':
        return 3;
      case 'approved':
        return 2;
      case 'submitted':
      case 'unpaid':
      case 'open':
        return 1;
      default:
        return 0;
    }
  }

  bool get _rejected =>
      status.toLowerCase() == 'rejected' || status.toLowerCase() == 'cancelled';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_rejected) {
      return Row(
        children: [
          Icon(Icons.cancel, color: scheme.error),
          const SizedBox(width: 8),
          Text(status, style: TextStyle(color: scheme.error)),
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < _stages.length; i++)
          _TimelineStep(
            label: _stages[i],
            done: i <= _currentIndex,
            isLast: i == _stages.length - 1,
          ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.done,
    required this.isLast,
  });

  final String label;
  final bool done;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = done ? scheme.primary : scheme.outlineVariant;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: color,
                size: 22,
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: color)),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
