import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/offline_banner.dart';
import '../../../core/ui/sync_status_indicator.dart';
import '../../../core/utils/locale_ext.dart';
import '../../authentication/presentation/providers/auth_notifier.dart';
import '../../settings/presentation/providers/settings_notifier.dart';
import '../../tenant/presentation/providers/tenant_notifier.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authNotifierProvider);
    final fullName = state is Authenticated
        ? (state.session.fullName ?? state.session.username)
        : '';
    final branding = ref.watch(currentBrandingProvider);
    final tenantState = ref.watch(tenantNotifierProvider);
    final tenantUrl =
        tenantState is TenantActive ? tenantState.tenant.erpUrl : null;
    final logoUrl = branding?.logoUrl(tenantUrl);
    final title = branding?.companyName ?? context.l10n.appName;
    final featureFlags = branding?.featureFlags ?? {};

    final recentRoutes =
        ref.watch(settingsNotifierProvider.select((s) => s.recentRoutes));

    return Scaffold(
      appBar: AppBar(
        leading: logoUrl != null
            ? Padding(
                padding: const EdgeInsets.all(8),
                child: ClipOval(
                  child: Image.network(
                    logoUrl,
                    width: 32,
                    height: 32,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.inventory_2),
                  ),
                ),
              )
            : null,
        title: Text(title),
        actions: [
          const SyncStatusIndicator(),
          IconButton(
            tooltip: context.l10n.logout,
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OfflineBanner(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.welcome(fullName),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (recentRoutes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _RecentlyUsedRow(routes: recentRoutes),
                  ],
                  const SizedBox(height: 16),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cols = constraints.maxWidth >= 600 ? 3 : 2;
                        return GridView.count(
                          crossAxisCount: cols,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          children: [
                            _NavCard(
                              icon: Icons.qr_code_scanner,
                              label: context.l10n.scan,
                              route: '/scan',
                            ),
                            _NavCard(
                              icon: Icons.search,
                              label: context.l10n.searchItems,
                              route: '/items',
                            ),
                            _NavCard(
                              icon: Icons.swap_horiz,
                              label: context.l10n.transfer,
                              route: '/transfer',
                            ),
                            _NavCard(
                              icon: Icons.input,
                              label: context.l10n.receive,
                              route: '/receipt',
                              enabled: featureFlags['receipt'] != false,
                            ),
                            _NavCard(
                              icon: Icons.fact_check,
                              label: context.l10n.count,
                              route: '/reconcile',
                              enabled:
                                  featureFlags['reconciliation'] != false,
                            ),
                            _NavCard(
                              icon: Icons.warehouse_outlined,
                              label: context.l10n.warehouses,
                              route: '/warehouses',
                            ),
                            _NavCard(
                              icon: Icons.bar_chart,
                              label: context.l10n.analytics,
                              route: '/analytics',
                            ),
                            _NavCard(
                              icon: Icons.settings,
                              label: context.l10n.settings,
                              route: '/settings',
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentlyUsedRow extends ConsumerWidget {
  final List<String> routes;
  const _RecentlyUsedRow({required this.routes});

  static const _routeLabels = {
    '/scan': ('Scan', Icons.qr_code_scanner),
    '/items': ('Search', Icons.search),
    '/transfer': ('Transfer', Icons.swap_horiz),
    '/receipt': ('Receive', Icons.input),
    '/reconcile': ('Count', Icons.fact_check),
    '/settings': ('Settings', Icons.settings),
    '/sync': ('Sync', Icons.sync),
    '/warehouses': ('Warehouses', Icons.warehouse_outlined),
    '/analytics': ('Analytics', Icons.bar_chart),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: routes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final route = routes[i];
          final (label, icon) =
              _routeLabels[route] ?? (route, Icons.chevron_right);
          return ActionChip(
            avatar: Icon(icon, size: 16),
            label: Text(label, style: const TextStyle(fontSize: 12)),
            onPressed: () {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .recordRouteVisit(route);
              context.push(route);
            },
          );
        },
      ),
    );
  }
}

class _NavCard extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool enabled;

  const _NavCard({
    required this.icon,
    required this.label,
    required this.route,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = !enabled;
    final iconColor = disabled ? scheme.outline : scheme.primary;
    final labelColor = disabled ? scheme.outline : scheme.onSurface;

    void navigate() {
      ref.read(settingsNotifierProvider.notifier).recordRouteVisit(route);
      context.push(route);
    }

    return Card(
      elevation: 0,
      color: disabled
          ? scheme.surfaceContainerLowest
          : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: disabled ? null : navigate,
        splashColor: scheme.primary.withValues(alpha: 0.12),
        highlightColor: scheme.primary.withValues(alpha: 0.05),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: disabled
                      ? Colors.transparent
                      : scheme.primaryContainer.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: iconColor),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (disabled)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Disabled',
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.outline,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
