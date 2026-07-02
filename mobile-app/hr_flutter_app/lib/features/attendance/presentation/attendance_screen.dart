import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/dialogs.dart';
import '../data/attendance_repository.dart';
import 'attendance_controller.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  String? _month;
  String? _day;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceControllerProvider);
    final checkedIn = state.status?.checkedIn ?? false;
    final months = _options(state.history.map((row) => _datePart(row.time, 1)));
    final days = _options(state.history.map((row) => _datePart(row.time, 2)));
    final history = state.history.where((row) {
      final monthMatches = _month == null || _datePart(row.time, 1) == _month;
      final dayMatches = _day == null || _datePart(row.time, 2) == _day;
      return monthMatches && dayMatches;
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.isLoading
                ? null
                : () => ref.read(attendanceControllerProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    checkedIn ? 'Checked in' : 'Not checked in',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text('Pending offline records: ${state.pendingCount}'),
                  if (state.pendingCount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: state.isLoading
                              ? null
                              : () => ref
                                  .read(attendanceControllerProvider.notifier)
                                  .retryPending(),
                          icon: const Icon(Icons.sync),
                          label: const Text('Retry pending'),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: state.isLoading
                              ? null
                              : () => _confirmDiscard(context, ref),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Discard'),
                        ),
                      ],
                    ),
                  ],
                  if (state.lastSyncError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.lastSyncError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (state.status?.lastCheckIn != null) ...[
                    const SizedBox(height: 8),
                    Text('Last check-in: ${state.status!.lastCheckIn}'),
                  ],
                  if (state.status?.lastCheckOut != null) ...[
                    const SizedBox(height: 4),
                    Text('Last check-out: ${state.status!.lastCheckOut}'),
                  ],
                  if (state.status?.shiftName != null) ...[
                    const SizedBox(height: 4),
                    Text('Shift: ${state.status!.shiftName}'),
                  ],
                  if (state.status?.holidayLabel != null) ...[
                    const SizedBox(height: 4),
                    Text('Holiday: ${state.status!.holidayLabel}'),
                  ],
                  if (state.status?.lateEntry == true ||
                      state.status?.earlyExit == true) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (state.status?.lateEntry == true)
                          const Chip(label: Text('Late entry')),
                        if (state.status?.earlyExit == true)
                          const Chip(label: Text('Early exit')),
                      ],
                    ),
                  ],
                  if (state.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: state.isLoading
                          ? null
                          : () => ref
                              .read(attendanceControllerProvider.notifier)
                              .load(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: checkedIn || state.isLoading
                              ? null
                              : () => ref
                                  .read(attendanceControllerProvider.notifier)
                                  .check('IN'),
                          icon: const Icon(Icons.login),
                          label: const Text('Check in'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: checkedIn && !state.isLoading
                              ? () => ref
                                  .read(attendanceControllerProvider.notifier)
                                  .check('OUT')
                              : null,
                          icon: const Icon(Icons.logout),
                          label: const Text('Check out'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('History', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _HistoryFilters(
            months: months,
            days: days,
            month: _month,
            day: _day,
            onMonthChanged: (value) => setState(() => _month = value),
            onDayChanged: (value) => setState(() => _day = value),
            onClear: _clearFilters,
          ),
          const SizedBox(height: 8),
          if (state.isLoading && state.history.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (history.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No attendance history found.'),
              ),
            )
          else
            ...history.map((row) => _HistoryTile(row: row)),
        ],
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _month = null;
      _day = null;
    });
  }

  static String? _datePart(String value, int index) {
    final date = value.split(' ').first;
    final parts = date.split('-');
    return parts.length > index && parts[index].isNotEmpty
        ? parts[index]
        : null;
  }

  static List<String> _options(Iterable<String?> values) {
    final rows = values.whereType<String>().toSet().toList()..sort();
    return rows;
  }

  Future<void> _confirmDiscard(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Discard pending records?',
      message:
          'Offline check-in/out records waiting to sync will be permanently removed.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (confirmed) {
      await ref.read(attendanceControllerProvider.notifier).discardPending();
    }
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({
    required this.months,
    required this.days,
    required this.month,
    required this.day,
    required this.onMonthChanged,
    required this.onDayChanged,
    required this.onClear,
  });

  final List<String> months;
  final List<String> days;
  final String? month;
  final String? day;
  final ValueChanged<String?> onMonthChanged;
  final ValueChanged<String?> onDayChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: month,
            decoration: const InputDecoration(labelText: 'Month'),
            items: [
              for (final value in months)
                DropdownMenuItem(value: value, child: Text(value)),
            ],
            onChanged: onMonthChanged,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: day,
            decoration: const InputDecoration(labelText: 'Day'),
            items: [
              for (final value in days)
                DropdownMenuItem(value: value, child: Text(value)),
            ],
            onChanged: onDayChanged,
          ),
        ),
        IconButton(
          tooltip: 'Clear history filters',
          onPressed: month == null && day == null ? null : onClear,
          icon: const Icon(Icons.filter_alt_off_outlined),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.row});

  final AttendanceHistoryRow row;

  @override
  Widget build(BuildContext context) {
    final isIn = row.logType.toUpperCase() == 'IN';
    return Card(
      child: ListTile(
        leading: Icon(isIn ? Icons.login : Icons.logout),
        title: Text(isIn ? 'Check in' : 'Check out'),
        subtitle: Text(row.time),
        trailing: Text(row.logType),
      ),
    );
  }
}
