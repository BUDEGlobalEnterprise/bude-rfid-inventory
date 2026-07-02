import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/offline/read_cache.dart';
import '../../attendance/presentation/attendance_controller.dart';
import '../../authentication/presentation/auth_controller.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/presentation/expenses_screen.dart';
import '../../leave/data/leave_repository.dart';
import '../../leave/presentation/leave_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    final attendance = ref.watch(attendanceControllerProvider);
    final leaveBalances = ref.watch(leaveBalancesProvider);
    final leaveRequests = ref.watch(leaveRequestsProvider);
    final expenses = ref.watch(expenseClaimsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bude HR'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(attendanceControllerProvider);
              ref.invalidate(leaveBalancesProvider);
              ref.invalidate(leaveRequestsProvider);
              ref.invalidate(expenseClaimsProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Hello, ${session?.fullName ?? 'Employee'}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          _AttendanceStatusCard(attendance: attendance),
          const SizedBox(height: 12),
          _AttendanceQuickAction(attendance: attendance),
          const SizedBox(height: 12),
          _LeaveSummaryCard(
            leaveBalances: leaveBalances,
            leaveRequests: leaveRequests,
          ),
          const SizedBox(height: 12),
          _ExpenseSummaryCard(expenses: expenses),
          if (session?.isManager == true) ...[
            const SizedBox(height: 12),
            const _ManagerSectionPlaceholder(),
          ],
          const SizedBox(height: 16),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionCard('/attendance', Icons.fingerprint, 'Attendance'),
              _ActionCard('/leave', Icons.event_available, 'Leave'),
              _ActionCard('/expenses', Icons.receipt_long, 'Expenses'),
              _ActionCard('/salary', Icons.payments, 'Salary'),
              _ActionCard('/profile', Icons.badge, 'Profile'),
              _ActionCard(
                '/notifications',
                Icons.notifications,
                'Notifications',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceStatusCard extends StatelessWidget {
  const _AttendanceStatusCard({required this.attendance});

  final AttendanceState attendance;

  @override
  Widget build(BuildContext context) {
    final status = attendance.status;
    final checkedIn = status?.checkedIn == true;
    final details = <String>[
      if (status?.lastCheckIn != null) 'In: ${status!.lastCheckIn}',
      if (status?.lastCheckOut != null) 'Out: ${status!.lastCheckOut}',
      if (status?.shiftName != null) 'Shift: ${status!.shiftName}',
      if (status?.holidayLabel != null) 'Holiday: ${status!.holidayLabel}',
      if (status?.lateEntry == true) 'Late entry',
      if (status?.earlyExit == true) 'Early exit',
      if (attendance.pendingCount > 0)
        '${attendance.pendingCount} offline attendance pending',
    ];
    return _SummaryCard(
      icon: Icons.fingerprint,
      title: 'Attendance',
      value: attendance.isLoading
          ? 'Loading'
          : checkedIn
              ? 'Checked in'
              : 'Checked out',
      detail: details.isEmpty ? 'No recent attendance data.' : details.join('\n'),
    );
  }
}

class _AttendanceQuickAction extends ConsumerWidget {
  const _AttendanceQuickAction({required this.attendance});

  final AttendanceState attendance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkedIn = attendance.status?.checkedIn == true;
    return FilledButton.icon(
      onPressed: attendance.isLoading
          ? null
          : () => ref
              .read(attendanceControllerProvider.notifier)
              .check(checkedIn ? 'OUT' : 'IN'),
      icon: Icon(checkedIn ? Icons.logout : Icons.login),
      label: Text(checkedIn ? 'Check out' : 'Check in'),
    );
  }
}

class _LeaveSummaryCard extends StatelessWidget {
  const _LeaveSummaryCard({
    required this.leaveBalances,
    required this.leaveRequests,
  });

  final AsyncValue<Cached<List<LeaveBalance>>> leaveBalances;
  final AsyncValue<List<LeaveApplication>> leaveRequests;

  @override
  Widget build(BuildContext context) {
    return leaveBalances.when(
      data: (cached) {
        final rows = cached.data;
        final pendingCount = leaveRequests.maybeWhen(
          data: _pendingLeaveCount,
          orElse: () => 0,
        );
        if (rows.isEmpty) {
          return _SummaryCard(
            icon: Icons.event_available,
            title: 'Leave',
            value: 'No balance',
            detail: pendingCount > 0
                ? '$pendingCount leave request(s) pending.'
                : 'Leave balances are not available yet.',
          );
        }
        final total = rows.fold<num>(
          0,
          (sum, row) => sum + row.available,
        );
        final top = rows.reduce(
          (current, next) => next.available > current.available ? next : current,
        );
        return _SummaryCard(
          icon: Icons.event_available,
          title: 'Leave',
          value: '$total days available',
          detail: pendingCount > 0
              ? '${top.leaveType}: ${top.available} left · '
                  '$pendingCount pending'
              : '${top.leaveType}: ${top.available} left',
        );
      },
      error: (_, __) => const _SummaryCard(
        icon: Icons.event_busy,
        title: 'Leave',
        value: 'Unavailable',
        detail: 'Tap refresh to try loading leave balances again.',
      ),
      loading: () => const _SummaryCard(
        icon: Icons.event_available,
        title: 'Leave',
        value: 'Loading',
        detail: 'Fetching leave balances.',
      ),
    );
  }

  int _pendingLeaveCount(List<LeaveApplication> rows) {
    return rows.where((row) {
      final status = row.status.toLowerCase();
      return !{'approved', 'rejected', 'cancelled'}.contains(status);
    }).length;
  }
}

class _ExpenseSummaryCard extends StatelessWidget {
  const _ExpenseSummaryCard({required this.expenses});

  final AsyncValue<List<ExpenseClaimSummary>> expenses;

  @override
  Widget build(BuildContext context) {
    return expenses.when(
      data: (rows) {
        final pending = rows.where((claim) {
          final status = claim.status.toLowerCase();
          return !{'paid', 'approved', 'cancelled', 'rejected'}.contains(status);
        }).length;
        return _SummaryCard(
          icon: Icons.receipt_long,
          title: 'Expenses',
          value: '$pending pending',
          detail: rows.isEmpty
              ? 'No expense claims found.'
              : '${rows.length} total claim records',
        );
      },
      error: (_, __) => const _SummaryCard(
        icon: Icons.receipt_long,
        title: 'Expenses',
        value: 'Unavailable',
        detail: 'Tap refresh to try loading expense claims again.',
      ),
      loading: () => const _SummaryCard(
        icon: Icons.receipt_long,
        title: 'Expenses',
        value: 'Loading',
        detail: 'Fetching expense claims.',
      ),
    );
  }
}

class _ManagerSectionPlaceholder extends StatelessWidget {
  const _ManagerSectionPlaceholder();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/manager'),
      child: const _SummaryCard(
        icon: Icons.supervisor_account_outlined,
        title: 'Manager tools',
        value: 'Review approvals',
        detail: 'Approve or reject pending leave and expense requests.',
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(detail),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(this.route, this.icon, this.label);

  final String route;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 112,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 28),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
