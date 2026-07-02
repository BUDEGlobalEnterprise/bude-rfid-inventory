import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/hr_api_client.dart';
import '../../../core/storage/secure_session_store.dart';
import '../../../core/widgets/async_states.dart';
import '../data/manager_repository.dart';

final managerRepositoryProvider = Provider<ManagerRepository>((ref) {
  return ManagerRepository(
    ref.watch(hrApiClientProvider),
    ref.watch(secureSessionStoreProvider),
  );
});

final managerSummaryProvider = FutureProvider((ref) {
  return ref.watch(managerRepositoryProvider).summary();
});

final pendingLeaveApprovalsProvider = FutureProvider((ref) {
  return ref.watch(managerRepositoryProvider).pendingLeaves();
});

final pendingExpenseApprovalsProvider = FutureProvider((ref) {
  return ref.watch(managerRepositoryProvider).pendingExpenses();
});

final directReportsProvider = FutureProvider((ref) {
  return ref.watch(managerRepositoryProvider).directReports();
});

class ManagerScreen extends ConsumerWidget {
  const ManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(managerSummaryProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manager'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () {
                ref.invalidate(managerSummaryProvider);
                ref.invalidate(directReportsProvider);
                ref.invalidate(pendingLeaveApprovalsProvider);
                ref.invalidate(pendingExpenseApprovalsProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Team'),
              Tab(text: 'Leave'),
              Tab(text: 'Expenses'),
            ],
          ),
        ),
        body: Column(
          children: [
            summary.maybeWhen(
              data: (data) => _SummaryHeader(summary: data),
              orElse: () => const SizedBox.shrink(),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _DirectReportsTab(),
                  _LeaveApprovalsTab(),
                  _ExpenseApprovalsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.summary});

  final ManagerSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              label: 'Pending leave',
              value: summary.pendingLeaves,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryTile(
              label: 'Pending expenses',
              value: summary.pendingExpenses,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _DirectReportsTab extends ConsumerWidget {
  const _DirectReportsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(directReportsProvider);
    return reports.when(
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(child: Text('No direct reports found.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final row in rows)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(row.employeeName),
                  subtitle: Text(
                    [
                      row.designation,
                      row.department,
                      row.companyEmail,
                      row.cellNumber,
                    ].where((value) => value.isNotEmpty).join(' · '),
                  ),
                ),
              ),
          ],
        );
      },
      error: (_, __) => ErrorRetry(
        message: 'Unable to load direct reports.',
        onRetry: () => ref.invalidate(directReportsProvider),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _LeaveApprovalsTab extends ConsumerWidget {
  const _LeaveApprovalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaves = ref.watch(pendingLeaveApprovalsProvider);
    return leaves.when(
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(child: Text('No pending leave approvals.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final row in rows)
              Card(
                child: ListTile(
                  title: Text(row.employeeName),
                  subtitle: Text(
                    '${row.leaveType} · ${row.fromDate} → ${row.toDate} '
                    '(${row.totalLeaveDays}d)',
                  ),
                  onTap: () => _decideLeave(context, ref, row),
                ),
              ),
          ],
        );
      },
      error: (_, __) => ErrorRetry(
        message: 'Unable to load approvals.',
        onRetry: () => ref.invalidate(pendingLeaveApprovalsProvider),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _decideLeave(
    BuildContext context,
    WidgetRef ref,
    PendingLeaveApproval row,
  ) async {
    final decision = await showApprovalDialog(
      context,
      title: row.employeeName,
      subtitle: '${row.leaveType} · ${row.fromDate} → ${row.toDate}',
    );
    if (decision == null) return;
    await ref.read(managerRepositoryProvider).decideLeave(
          row.name,
          approved: decision.approved,
          comment: decision.comment,
        );
    ref.invalidate(pendingLeaveApprovalsProvider);
    ref.invalidate(managerSummaryProvider);
  }
}

class _ExpenseApprovalsTab extends ConsumerWidget {
  const _ExpenseApprovalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(pendingExpenseApprovalsProvider);
    return expenses.when(
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(child: Text('No pending expense approvals.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final row in rows)
              Card(
                child: ListTile(
                  title: Text(row.employeeName),
                  subtitle: Text('${row.postingDate} · ${row.totalClaimedAmount}'),
                  onTap: () => _decideExpense(context, ref, row),
                ),
              ),
          ],
        );
      },
      error: (_, __) => ErrorRetry(
        message: 'Unable to load approvals.',
        onRetry: () => ref.invalidate(pendingExpenseApprovalsProvider),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _decideExpense(
    BuildContext context,
    WidgetRef ref,
    PendingExpenseApproval row,
  ) async {
    final decision = await showApprovalDialog(
      context,
      title: row.employeeName,
      subtitle: 'Claim ${row.totalClaimedAmount} · ${row.postingDate}',
    );
    if (decision == null) return;
    await ref.read(managerRepositoryProvider).decideExpense(
          row.name,
          approved: decision.approved,
          comment: decision.comment,
        );
    ref.invalidate(pendingExpenseApprovalsProvider);
    ref.invalidate(managerSummaryProvider);
  }
}

class ApprovalDecision {
  const ApprovalDecision({required this.approved, this.comment});
  final bool approved;
  final String? comment;
}

/// Shared approve/reject dialog. Doubles as the approval detail view
/// (employee + request summary) plus a comment field and confirmation.
// ponytail: one dialog instead of a separate detail screen + action sheet;
// split out if approvals grow richer fields.
Future<ApprovalDecision?> showApprovalDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
}) {
  final comment = TextEditingController();
  return showDialog<ApprovalDecision>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(subtitle),
          const SizedBox(height: 12),
          TextField(
            controller: comment,
            decoration: const InputDecoration(labelText: 'Comment (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            ApprovalDecision(approved: false, comment: comment.text),
          ),
          child: const Text('Reject'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            ApprovalDecision(approved: true, comment: comment.text),
          ),
          child: const Text('Approve'),
        ),
      ],
    ),
  );
}
