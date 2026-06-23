import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/authentication/presentation/providers/auth_notifier.dart';
import '../../../features/tenant/presentation/providers/tenant_notifier.dart';
import 'providers/dashboard_prefs_notifier.dart';

// Stable IDs and display names for dashboard sections.
const _sectionLabels = <String, String>{
  'ops': 'Operations KPIs',
  'assets': 'Asset Overview',
  'quick_actions': 'Quick Actions',
  'recent_activity': 'Recent Activity',
  'system_status': 'System Status',
};

// Stable IDs and display names for quick actions.
const _actionLabels = <String, String>{
  'scan': 'Scan',
  'search': 'Search Items',
  'assets': 'Assets',
  'move_asset': 'Move Asset',
  'transfer': 'Transfer',
  'receive': 'Receive',
  'count': 'Count',
  'reports': 'Reports',
};

// Actions that require Stock Manager or Stock User role.
const _opsActions = {'move_asset', 'transfer', 'receive', 'count'};

// Actions that require Stock Manager role.
const _managerActions = {'reports'};

void showDashboardEditSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _DashboardEditSheet(),
  );
}

class _DashboardEditSheet extends ConsumerWidget {
  const _DashboardEditSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(dashboardPrefsNotifierProvider);
    final notifier = ref.read(dashboardPrefsNotifierProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    final roles = ref.watch(rolesProvider);
    final isManager = roles.contains('Stock Manager');
    final canAccessOps =
        isManager || roles.contains('Stock User') || roles.isEmpty;
    final branding = ref.watch(currentBrandingProvider);
    final featureFlags = branding?.featureFlags ?? {};

    final visibleActions = _actionLabels.keys.where((id) {
      if (_managerActions.contains(id)) return isManager;
      if (_opsActions.contains(id)) {
        if (!canAccessOps) return false;
        if (id == 'receive') return featureFlags['receipt'] != false;
        if (id == 'count') return featureFlags['reconciliation'] != false;
      }
      return true;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle + title
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Customize Dashboard',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  // ── Section order & visibility ──────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'SECTIONS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 1.2,
                          ),
                    ),
                  ),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorderItem: (oldIndex, newIndex) {
                      final order = List<String>.from(prefs.cardOrder);
                      final item = order.removeAt(oldIndex);
                      order.insert(newIndex, item);
                      notifier.reorder(order);
                    },
                    children: [
                      for (final id in prefs.cardOrder)
                        ListTile(
                          key: ValueKey(id),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          leading: Switch(
                            value: !prefs.hiddenCards.contains(id),
                            onChanged: (_) => notifier.toggleVisibility(id),
                          ),
                          title: Text(
                            _sectionLabels[id] ?? id,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          trailing: ReorderableDragStartListener(
                            index: prefs.cardOrder.indexOf(id),
                            child: const Icon(Icons.drag_handle),
                          ),
                        ),
                    ],
                  ),

                  // ── Quick action visibility ─────────────────────────────
                  if (visibleActions.isNotEmpty) ...[
                    const Divider(height: 32),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        'QUICK ACTIONS',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  letterSpacing: 1.2,
                                ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in visibleActions)
                            FilterChip(
                              label: Text(_actionLabels[id] ?? id),
                              selected: !prefs.hiddenActions.contains(id),
                              onSelected: (_) => notifier.toggleAction(id),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
