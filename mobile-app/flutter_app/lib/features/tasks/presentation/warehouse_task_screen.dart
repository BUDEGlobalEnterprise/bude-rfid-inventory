import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/loading_shimmer.dart';
import '../../../core/ui/operational_components.dart';
import '../../../core/utils/locale_ext.dart';
import '../../fulfillment/domain/fulfillment_route_extra.dart';
import '../../receipt/domain/receipt_route_extra.dart';
import '../domain/warehouse_task.dart';
import 'providers/warehouse_task_providers.dart';

class WarehouseTaskScreen extends ConsumerStatefulWidget {
  const WarehouseTaskScreen({super.key});

  @override
  ConsumerState<WarehouseTaskScreen> createState() =>
      _WarehouseTaskScreenState();
}

class _WarehouseTaskScreenState extends ConsumerState<WarehouseTaskScreen> {
  WarehouseTaskFilter _filter = WarehouseTaskFilter.all;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(warehouseTasksProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            tooltip: 'Refresh tasks',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(warehouseTasksProvider),
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const ShimmerList(count: 8),
        error: (e, _) => _TaskError(
          message: _taskErrorMessage(e),
          onRetry: () => ref.invalidate(warehouseTasksProvider),
        ),
        data: (tasks) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(warehouseTasksProvider),
          child: _TaskList(
            tasks: tasks,
            filter: _filter,
            onFilterChanged: (filter) => setState(() => _filter = filter),
          ),
        ),
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  final List<WarehouseTask> tasks;
  final WarehouseTaskFilter filter;
  final ValueChanged<WarehouseTaskFilter> onFilterChanged;

  const _TaskList({
    required this.tasks,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(currentUsernameProvider);
    final filtered = _filterTasks(tasks, filter, username);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BudeOperationHeader(
          icon: Icons.task_alt_outlined,
          title: 'Warehouse tasks',
          subtitle: 'Open ERP work assigned to the floor.',
          pills: [
            BudeSummaryPill(
              icon: Icons.assignment_outlined,
              label: 'Open',
              value: '${tasks.length}',
            ),
            BudeSummaryPill(
              icon: Icons.person_outline,
              label: 'Mine',
              value: '${_assignedTo(tasks, username).length}',
            ),
            BudeStatusChip(
              label: _filterLabel(filter),
              icon: Icons.filter_list,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TaskFilters(selected: filter, onChanged: onFilterChanged),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          EmptyStateView(
            icon: Icons.task_alt_outlined,
            title: 'No warehouse tasks',
            subtitle: filter == WarehouseTaskFilter.all
                ? 'Open Purchase Orders, Sales Orders, and maintenance work will appear here.'
                : 'No tasks match this filter.',
          )
        else
          ..._prioritySections(filtered).entries.expand(
            (entry) => [
              _SectionHeader(title: entry.key, count: entry.value.length),
              ...entry.value.map((task) => _TaskTile(task: task)),
              const SizedBox(height: 12),
            ],
          ),
      ],
    );
  }

  List<WarehouseTask> _filterTasks(
    List<WarehouseTask> tasks,
    WarehouseTaskFilter filter,
    String? username,
  ) {
    return switch (filter) {
      WarehouseTaskFilter.all => tasks,
      WarehouseTaskFilter.assignedToMe => _assignedTo(tasks, username),
      WarehouseTaskFilter.receiving => tasks
          .where((task) => task.kind == WarehouseTaskKind.receivePurchaseOrder)
          .toList(),
      WarehouseTaskFilter.fulfillment => tasks
          .where((task) => task.kind == WarehouseTaskKind.fulfillSalesOrder)
          .toList(),
      WarehouseTaskFilter.assetMaintenance => tasks
          .where((task) => task.kind == WarehouseTaskKind.assetMaintenance)
          .toList(),
    };
  }

  List<WarehouseTask> _assignedTo(List<WarehouseTask> tasks, String? username) {
    final clean = (username ?? '').trim().toLowerCase();
    if (clean.isEmpty) return const [];
    return tasks
        .where((task) => (task.assignedTo ?? '').trim().toLowerCase() == clean)
        .toList();
  }

  Map<String, List<WarehouseTask>> _prioritySections(
    List<WarehouseTask> tasks,
  ) {
    final result = <String, List<WarehouseTask>>{};
    for (final task in tasks) {
      final key = '${task.priority} priority';
      result.putIfAbsent(key, () => []).add(task);
    }
    return result;
  }
}

class _TaskFilters extends StatelessWidget {
  final WarehouseTaskFilter selected;
  final ValueChanged<WarehouseTaskFilter> onChanged;

  const _TaskFilters({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in WarehouseTaskFilter.values) ...[
            FilterChip(
              label: Text(_filterLabel(filter)),
              selected: selected == filter,
              onSelected: (_) => onChanged(filter),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$title ($count)',
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final WarehouseTask task;

  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: ListTile(
          leading: Icon(_taskIcon(task.kind)),
          title: Text(task.title),
          subtitle: Text(_subtitle(context, task)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openTask(context, task),
        ),
      ),
    );
  }

  String _subtitle(BuildContext context, WarehouseTask task) {
    final parts = <String>[
      task.subtitle,
      if (task.dueDate != null) context.l10n.dueDate(task.dueDate!),
      if (task.assignedTo != null) 'Assigned to ${task.assignedTo}',
      if (task.itemCount > 0) '${task.itemCount} lines',
      if (task.pendingQty > 0) 'Qty ${formatOperationalQty(task.pendingQty)}',
    ];
    return parts.where((part) => part.trim().isNotEmpty).join(' - ');
  }

  void _openTask(BuildContext context, WarehouseTask task) {
    switch (task.kind) {
      case WarehouseTaskKind.receivePurchaseOrder:
        context.push(
          '/receipt',
          extra: ReceiptRouteExtra(
            againstPo: task.sourceName,
            todoName: task.todoName,
          ),
        );
      case WarehouseTaskKind.fulfillSalesOrder:
        context.push(
          '/fulfillment/${Uri.encodeComponent(task.sourceName)}',
          extra: FulfillmentRouteExtra(todoName: task.todoName),
        );
      case WarehouseTaskKind.assetMaintenance:
        final asset = (task.assetName ?? '').trim();
        if (asset.isEmpty) {
          context.push('/assets');
          return;
        }
        final params = {
          'log': task.sourceName,
          if ((task.todoName ?? '').trim().isNotEmpty)
            'todo': task.todoName!.trim(),
        };
        final query = Uri(queryParameters: params).query;
        context.push('/assets/${Uri.encodeComponent(asset)}?$query');
    }
  }
}

class _TaskError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _TaskError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EmptyStateView(
          icon: Icons.sync_problem_outlined,
          title: 'Could not load tasks',
          subtitle: message,
          action: OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            onPressed: onRetry,
          ),
        ),
      ],
    );
  }
}

String _filterLabel(WarehouseTaskFilter filter) => switch (filter) {
      WarehouseTaskFilter.all => 'All',
      WarehouseTaskFilter.assignedToMe => 'Assigned to me',
      WarehouseTaskFilter.receiving => 'Receiving',
      WarehouseTaskFilter.fulfillment => 'Fulfillment',
      WarehouseTaskFilter.assetMaintenance => 'Asset maintenance',
    };

IconData _taskIcon(WarehouseTaskKind kind) => switch (kind) {
      WarehouseTaskKind.receivePurchaseOrder => Icons.input_outlined,
      WarehouseTaskKind.fulfillSalesOrder => Icons.local_shipping_outlined,
      WarehouseTaskKind.assetMaintenance => Icons.engineering_outlined,
    };

String _taskErrorMessage(Object error) => switch (error) {
      NetworkException(:final message) => message,
      AuthException(:final message) => message,
      ServerException(:final message) => message,
      _ => error.toString(),
    };
