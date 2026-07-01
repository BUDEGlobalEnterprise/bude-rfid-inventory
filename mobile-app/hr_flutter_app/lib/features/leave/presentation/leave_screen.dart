import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/hr_api_client.dart';
import '../../../core/storage/secure_session_store.dart';
import '../data/leave_repository.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepository(
    ref.watch(hrApiClientProvider),
    ref.watch(secureSessionStoreProvider),
  );
});

final leaveBalancesProvider = FutureProvider((ref) {
  return ref.watch(leaveRepositoryProvider).balances();
});

class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(leaveBalancesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Leave')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _LeaveDialog(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Apply'),
      ),
      body: balances.when(
        data: (rows) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) {
            final row = rows[index];
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              tileColor: Theme.of(context).colorScheme.surface,
              title: Text(row.leaveType),
              subtitle: Text('Used ${row.used} of ${row.allocated}'),
              trailing: Text('${row.available} left'),
            );
          },
        ),
        error: (_, __) => const Center(child: Text('Unable to load leave.')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _LeaveDialog extends ConsumerStatefulWidget {
  const _LeaveDialog();

  @override
  ConsumerState<_LeaveDialog> createState() => _LeaveDialogState();
}

class _LeaveDialogState extends ConsumerState<_LeaveDialog> {
  final _type = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();

  @override
  void dispose() {
    _type.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Apply for leave'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _type, decoration: const InputDecoration(labelText: 'Leave type')),
          TextField(controller: _from, decoration: const InputDecoration(labelText: 'From date')),
          TextField(controller: _to, decoration: const InputDecoration(labelText: 'To date')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            await ref.read(leaveRepositoryProvider).apply(
                  leaveType: _type.text,
                  fromDate: _from.text,
                  toDate: _to.text,
                );
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
