import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/hr_api_client.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/last_refreshed_label.dart';
import '../../../core/storage/secure_session_store.dart';
import '../data/leave_repository.dart';
import 'leave_detail_screen.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepository(
    ref.watch(hrApiClientProvider),
    ref.watch(secureSessionStoreProvider),
  );
});

final leaveBalancesProvider = FutureProvider((ref) {
  return ref.watch(leaveRepositoryProvider).balances();
});

final leaveRequestsProvider = FutureProvider((ref) {
  return ref.watch(leaveRepositoryProvider).requests();
});

class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leave'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Requests'),
              Tab(text: 'Balances'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const _LeaveDialog(),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Apply'),
        ),
        body: const TabBarView(
          children: [
            _RequestsTab(),
            _BalancesTab(),
          ],
        ),
      ),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(leaveRequestsProvider);
    return requests.when(
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(child: Text('No leave requests yet.'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(leaveRequestsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final row = rows[index];
              return Card(
                child: ListTile(
                  title: Text(row.leaveType),
                  subtitle: Text('${row.fromDate} → ${row.toDate}'),
                  trailing: LeaveStatusChip(status: row.status),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LeaveDetailScreen(name: row.name),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      error: (_, __) => ErrorRetry(
        message: 'Unable to load leave requests.',
        onRetry: () => ref.invalidate(leaveRequestsProvider),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _BalancesTab extends ConsumerWidget {
  const _BalancesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(leaveBalancesProvider);
    return balances.when(
      data: (cached) {
        final rows = cached.data;
        if (rows.isEmpty) {
          return const Center(child: Text('No leave balances available.'));
        }
        return Column(
          children: [
            LastRefreshedLabel(
              fetchedAt: cached.fetchedAt,
              fromCache: cached.fromCache,
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  final row = rows[index];
                  return Card(
                    child: ListTile(
                      title: Text(row.leaveType),
                      subtitle: Text('Used ${row.used} of ${row.allocated}'),
                      trailing: Text('${row.available} left'),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      error: (_, __) => ErrorRetry(
        message: 'Unable to load leave balances.',
        onRetry: () => ref.invalidate(leaveBalancesProvider),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

/// Colour-coded status chip shared by the list and detail screens.
class LeaveStatusChip extends StatelessWidget {
  const LeaveStatusChip({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status.toLowerCase()) {
      'approved' => Colors.green,
      'rejected' || 'cancelled' => scheme.error,
      _ => scheme.primary,
    };
    return Chip(
      label: Text(status.isEmpty ? 'Draft' : status),
      labelStyle: TextStyle(color: color),
      side: BorderSide(color: color),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }
}

class _LeaveDialog extends ConsumerStatefulWidget {
  const _LeaveDialog();

  @override
  ConsumerState<_LeaveDialog> createState() => _LeaveDialogState();
}

class _LeaveDialogState extends ConsumerState<_LeaveDialog> {
  String? _type;
  DateTime? _from;
  DateTime? _to;
  bool _halfDay = false;
  final _reason = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  static String _fmt(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _pick({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  String? _validate() {
    if (_type == null || _type!.isEmpty) return 'Select a leave type.';
    if (_from == null || _to == null) return 'Select both dates.';
    if (_to!.isBefore(_from!)) return 'To date must be on or after from date.';
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
    try {
      await ref.read(leaveRepositoryProvider).apply(
            leaveType: _type!,
            fromDate: _fmt(_from!),
            toDate: _fmt(_to!),
            reason: _reason.text.isEmpty ? null : _reason.text,
            halfDay: _halfDay,
            halfDayDate: _fmt(_from!),
          );
      ref.invalidate(leaveRequestsProvider);
      ref.invalidate(leaveBalancesProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Unable to submit leave. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final balances = ref.watch(leaveBalancesProvider);
    final types = balances.maybeWhen(
      data: (cached) => cached.data.map((row) => row.leaveType).toList(),
      orElse: () => const <String>[],
    );
    return AlertDialog(
      title: const Text('Apply for leave'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Leave type'),
            items: [
              for (final type in types)
                DropdownMenuItem(value: type, child: Text(type)),
            ],
            onChanged: (value) => setState(() => _type = value),
          ),
          const SizedBox(height: 8),
          _DateField(
            label: 'From date',
            value: _from == null ? null : _fmt(_from!),
            onTap: () => _pick(isFrom: true),
          ),
          _DateField(
            label: 'To date',
            value: _to == null ? null : _fmt(_to!),
            onTap: () => _pick(isFrom: false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Half day'),
            value: _halfDay,
            onChanged: _submitting
                ? null
                : (value) => setState(() => _halfDay = value ?? false),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reason,
            decoration: const InputDecoration(labelText: 'Reason (optional)'),
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
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(value ?? 'Select date'),
      ),
    );
  }
}
