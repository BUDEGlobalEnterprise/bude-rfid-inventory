import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/locale_ext.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.analytics)),
      body: ListView(
        children: [
          _AnalyticsTile(
            icon: Icons.hourglass_bottom,
            title: l10n.stockAging,
            subtitle: l10n.stockAgingSubtitle,
            route: '/analytics/aging',
          ),
          const Divider(height: 0),
          _AnalyticsTile(
            icon: Icons.balance,
            title: l10n.varianceDashboard,
            subtitle: l10n.varianceDashboardSubtitle,
            route: '/analytics/variance',
          ),
          const Divider(height: 0),
          _AnalyticsTile(
            icon: Icons.bar_chart,
            title: l10n.throughput,
            subtitle: l10n.throughputSubtitle,
            route: '/analytics/throughput',
          ),
          const Divider(height: 0),
          _AnalyticsTile(
            icon: Icons.download,
            title: l10n.exportData,
            subtitle: l10n.exportDataSubtitle,
            route: '/analytics/export',
          ),
        ],
      ),
    );
  }
}

class _AnalyticsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  const _AnalyticsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }
}
