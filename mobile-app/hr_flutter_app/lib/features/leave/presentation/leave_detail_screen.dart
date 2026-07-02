import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/snackbars.dart';
import '../data/leave_repository.dart';
import 'leave_screen.dart';

final leaveDetailProvider =
    FutureProvider.family<LeaveApplication, String>((ref, name) {
  return ref.watch(leaveRepositoryProvider).detail(name);
});

class LeaveDetailScreen extends ConsumerWidget {
  const LeaveDetailScreen({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(leaveDetailProvider(name));
    return Scaffold(
      appBar: AppBar(title: const Text('Leave request')),
      body: detail.when(
        data: (row) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LeaveStatusChip(status: row.status),
            const SizedBox(height: 16),
            _DetailRow('Leave type', row.leaveType),
            _DetailRow('From', row.fromDate),
            _DetailRow('To', row.toDate),
            _DetailRow('Days', '${row.totalLeaveDays}'),
            if (row.description.isNotEmpty)
              _DetailRow('Reason', row.description),
            if (row.cancellable) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _confirmCancel(context, ref),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel request'),
              ),
            ],
          ],
        ),
        error: (_, __) => const Center(
          child: Text('Unable to load this leave request.'),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Cancel leave request?',
      message: 'This will cancel the submitted leave application.',
      confirmLabel: 'Cancel request',
      cancelLabel: 'Keep',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(leaveRepositoryProvider).cancel(name);
      ref.invalidate(leaveRequestsProvider);
      ref.invalidate(leaveBalancesProvider);
      ref.invalidate(leaveDetailProvider(name));
      if (context.mounted) Navigator.pop(context);
    } catch (_) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Unable to cancel leave request.');
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
