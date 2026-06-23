import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/empty_state_view.dart';
import '../data/alerts_remote_data_source.dart';
import 'providers/alerts_providers.dart';

const _categoryLabels = {
  'maintenance_due': 'Maintenance due',
  'assets_in_maintenance': 'Assets in maintenance',
  'out_of_stock': 'Out of stock',
  'low_stock': 'Low stock',
};

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: alertsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child:
                Text('Failed to load alerts: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (result) {
          if (result.alerts.isEmpty) {
            return const EmptyStateView(
              icon: Icons.check_circle_outline,
              title: 'All clear',
              subtitle: 'No open alerts right now.',
            );
          }
          // Group by category, preserving server order.
          final grouped = <String, List<Alert>>{};
          for (final a in result.alerts) {
            grouped.putIfAbsent(a.category, () => []).add(a);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(alertsProvider),
            child: ListView(
              children: [
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      '${_categoryLabels[entry.key] ?? entry.key} '
                      '(${entry.value.length})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  for (final a in entry.value) _AlertTile(alert: a),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final Alert alert;
  const _AlertTile({required this.alert});

  void _open(BuildContext context) {
    switch (alert.refDoctype) {
      case 'Asset':
        context.push('/assets/${Uri.encodeComponent(alert.refName)}');
      case 'Item':
        context.push('/items/${Uri.encodeComponent(alert.refName)}');
      // Asset Maintenance Log has no standalone screen — no-op.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final high = alert.severity == 'high';
    final color = high ? scheme.error : scheme.tertiary;
    final tappable = alert.refDoctype == 'Asset' || alert.refDoctype == 'Item';

    return ListTile(
      leading: Icon(
        high ? Icons.warning_amber : Icons.info_outline,
        color: color,
      ),
      title: Text(alert.title),
      subtitle: alert.subtitle.isEmpty ? null : Text(alert.subtitle),
      trailing: tappable ? const Icon(Icons.chevron_right) : null,
      onTap: tappable ? () => _open(context) : null,
    );
  }
}
