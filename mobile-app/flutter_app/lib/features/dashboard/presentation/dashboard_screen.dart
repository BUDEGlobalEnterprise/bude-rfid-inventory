import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/sync/pending_operation.dart';
import '../../../core/sync/providers.dart';
import '../../../core/ui/app_shell.dart';
import '../../../core/ui/operational_components.dart';
import '../../../core/ui/sync_status_indicator.dart';
import '../../../core/utils/locale_ext.dart';
import '../../alerts/presentation/providers/alerts_providers.dart';
import '../../analytics/presentation/providers/analytics_providers.dart';
import '../../authentication/presentation/providers/auth_notifier.dart';
import '../../reports/presentation/providers/reports_providers.dart';
import '../../settings/presentation/providers/settings_notifier.dart';
import '../../tenant/presentation/providers/tenant_notifier.dart';
import 'dashboard_edit_sheet.dart';
import 'providers/dashboard_providers.dart';
import 'providers/dashboard_prefs_notifier.dart';

const _kMaxContentWidth = 1100.0;

String _sectionLabel(String id) => switch (id) {
      'ops' => 'Operations KPIs',
      'assets' => 'Asset Overview',
      'quick_actions' => 'Quick Actions',
      'recent_activity' => 'Recent Activity',
      'system_status' => 'System Status',
      _ => id,
    };

IconData _sectionIcon(String id) => switch (id) {
      'ops' => Icons.today,
      'assets' => Icons.precision_manufacturing,
      'quick_actions' => Icons.bolt,
      'recent_activity' => Icons.history,
      'system_status' => Icons.monitor_heart_outlined,
      _ => Icons.dashboard,
    };

Widget _contentFor(String id) => switch (id) {
      'ops' => const _KpiGrid(),
      'assets' => const _AssetKpiRow(),
      'quick_actions' => const _QuickActionsContent(),
      'recent_activity' => const _RecentActivityContent(),
      'system_status' => const _SystemStatusContent(),
      _ => const SizedBox.shrink(),
    };

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final fullName = auth is Authenticated
        ? (auth.session.fullName ?? auth.session.username)
        : '';
    final branding = ref.watch(currentBrandingProvider);
    final tenantState = ref.watch(tenantNotifierProvider);
    final tenantUrl =
        tenantState is TenantActive ? tenantState.tenant.erpUrl : null;
    final logoUrl = branding?.logoUrl(tenantUrl);
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    final prefs = ref.watch(dashboardPrefsNotifierProvider);
    final visibleSections =
        prefs.cardOrder.where((id) => !prefs.hiddenCards.contains(id)).toList();

    final sectionWidgets = <Widget>[
      for (final id in visibleSections) ...[
        _CollapsibleSection(
          id: id,
          title: _sectionLabel(id),
          icon: _sectionIcon(id),
          child: _contentFor(id),
        ),
        const SizedBox(height: 16),
      ],
    ];

    return Scaffold(
      drawer: isMobile ? const AppNavDrawer() : null,
      appBar: AppBar(
        titleSpacing: 8,
        leading: isMobile
            ? null
            : (logoUrl != null
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
                : null),
        title: isMobile
            ? const Text('Dashboard')
            : GestureDetector(
                onTap: () => context.push('/items'),
                child: SearchBar(
                  hintText: context.l10n.searchItems,
                  leading: const Icon(Icons.search),
                  onSubmitted: (q) =>
                      context.push('/items', extra: {'query': q}),
                ),
              ),
        actions: [
          if (isMobile)
            IconButton(
              tooltip: context.l10n.searchItems,
              icon: const Icon(Icons.search),
              onPressed: () => context.push('/items'),
            ),
          const _NotificationsBell(),
          const SyncStatusIndicator(),
          IconButton(
            tooltip: 'Customize dashboard',
            icon: const Icon(Icons.tune),
            onPressed: () => showDashboardEditSheet(context),
          ),
          _UserMenu(fullName: fullName),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.welcome(fullName),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                const _CommandStrip(),
                const SizedBox(height: 18),
                if (visibleSections.isEmpty)
                  _EmptyDashboard(
                    onCustomize: () => showDashboardEditSheet(context),
                  )
                else
                  ...sectionWidgets,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Collapsible section wrapper ───────────────────────────────────────────────

class _CollapsibleSection extends ConsumerWidget {
  final String id;
  final String title;
  final IconData icon;
  final Widget child;

  const _CollapsibleSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isCollapsed =
        ref.watch(dashboardPrefsNotifierProvider).collapsedCards.contains(id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => ref
              .read(dashboardPrefsNotifierProvider.notifier)
              .toggleCollapsed(id),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  isCollapsed ? Icons.expand_more : Icons.expand_less,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: isCollapsed
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: child,
                ),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyDashboard extends StatelessWidget {
  final VoidCallback onCustomize;
  const _EmptyDashboard({required this.onCustomize});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dashboard_customize_outlined,
            size: 56,
            color: scheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Your dashboard is empty',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap Customize to show sections.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCustomize,
            icon: const Icon(Icons.tune),
            label: const Text('Customize'),
          ),
        ],
      ),
    );
  }
}

// ── AppBar: notifications bell ────────────────────────────────────────────────

class _CommandStrip extends ConsumerWidget {
  const _CommandStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final pending = ref.watch(unresolvedOpCountProvider).valueOrNull ?? 0;
    final alertCount = ref.watch(alertCountProvider);
    final settings = ref.watch(settingsNotifierProvider);
    final warehouse =
        settings.defaultSourceWarehouse ?? context.l10n.noDefaultWarehouse;

    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.push('/sync'),
              child: BudeStatusChip(
                label: pending == 0
                    ? context.l10n.syncClear
                    : context.l10n.pendingCountShort(pending),
                icon: pending == 0 ? Icons.cloud_done : Icons.sync_problem,
                color: pending == 0 ? scheme.secondary : scheme.error,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.push('/alerts'),
              child: BudeStatusChip(
                label: alertCount == 0
                    ? context.l10n.noAlerts
                    : context.l10n.alertsCountShort(alertCount),
                icon: alertCount == 0
                    ? Icons.notifications_none
                    : Icons.notifications_active,
                color: alertCount == 0 ? scheme.primary : scheme.error,
              ),
            ),
            BudeStatusChip(
              label: online ? 'Online' : 'Offline',
              icon: online ? Icons.wifi : Icons.wifi_off,
              color: online ? scheme.secondary : scheme.error,
            ),
            BudeStatusChip(
              label: warehouse,
              icon: Icons.warehouse_outlined,
              color: scheme.tertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsBell extends ConsumerWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = ref.watch(allOpsProvider).valueOrNull?.where(
              (o) =>
                  o.status == OpStatus.failed ||
                  o.status == OpStatus.pendingApproval,
            ) ??
        const [];
    final alertCount = ref.watch(alertCountProvider);
    final count = failed.length + alertCount;

    return IconButton(
      tooltip: 'Alerts & notifications',
      onPressed: () => context.push('/alerts'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

// ── AppBar: user avatar menu ──────────────────────────────────────────────────

class _UserMenu extends ConsumerWidget {
  final String fullName;
  const _UserMenu({required this.fullName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final initials = _initials(fullName);
    final roles = ref.watch(rolesProvider);
    final roleLabel = roles.isEmpty ? 'No role' : roles.first;

    return PopupMenuButton<String>(
      tooltip: fullName.isEmpty ? 'Account' : fullName,
      offset: const Offset(0, 48),
      onSelected: (v) {
        if (v == 'logout') {
          ref.read(authNotifierProvider.notifier).logout();
        } else if (v == 'settings') {
          context.go('/settings');
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName.isEmpty ? 'Signed in' : fullName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                roleLabel,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'settings', child: Text('Settings')),
        const PopupMenuItem(value: 'logout', child: Text('Logout')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: scheme.primaryContainer,
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

// ── Operations KPI grid ───────────────────────────────────────────────────────

class _KpiGrid extends ConsumerWidget {
  const _KpiGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final throughput = ref.watch(throughputProvider);
    final todayOps = ref.watch(todayOpCountProvider);
    final pendingSync = ref.watch(unresolvedOpCountProvider);

    final loading = throughput.isLoading;
    final successRate = throughput.valueOrNull?.successRate;

    final cards = <Widget>[
      _KpiCard(
        icon: Icons.today,
        label: "Today's Operations",
        value: loading ? null : '$todayOps',
        background: scheme.primaryContainer,
        foreground: scheme.onPrimaryContainer,
        onTap: () => context.push('/audit'),
      ),
      _KpiCard(
        icon: Icons.sync_problem_outlined,
        label: 'Pending Sync',
        value: pendingSync.valueOrNull == null ? null : '${pendingSync.value}',
        background: scheme.tertiaryContainer,
        foreground: scheme.onTertiaryContainer,
        onTap: () => context.push('/sync'),
      ),
      _KpiCard(
        icon: Icons.verified_outlined,
        label: 'Sync Success Rate',
        value: loading || successRate == null
            ? null
            : '${(successRate * 100).round()}%',
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
        onTap: () => context.push('/sync'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 700 ? 3 : 2;
        return _wrapGrid(cards, c.maxWidth, cols, aspect: 1.7, spacing: 12);
      },
    );
  }
}

// ── Asset KPI row ─────────────────────────────────────────────────────────────

class _AssetKpiRow extends ConsumerWidget {
  const _AssetKpiRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final kpis = ref.watch(assetKpisProvider);
    final data = kpis.valueOrNull;
    String? v(int? n) => kpis.isLoading ? null : '${n ?? 0}';

    final cards = <Widget>[
      _KpiCard(
        icon: Icons.precision_manufacturing,
        label: 'Total Assets',
        value: v(data?.totalAssets),
        background: scheme.surfaceContainerHighest,
        foreground: scheme.onSurface,
        onTap: () => context.push('/assets'),
      ),
      _KpiCard(
        icon: Icons.payments_outlined,
        label: 'Asset Value',
        value:
            kpis.isLoading ? null : (data?.totalValue ?? 0).round().toString(),
        background: scheme.surfaceContainerHighest,
        foreground: scheme.onSurface,
      ),
      _KpiCard(
        icon: Icons.build_circle_outlined,
        label: 'In Maintenance',
        value: v(data?.inMaintenance),
        background: scheme.surfaceContainerHighest,
        foreground: scheme.onSurface,
        onTap: () => context.push('/assets'),
      ),
      _KpiCard(
        icon: Icons.event_outlined,
        label: 'Upcoming Maint.',
        value: v(data?.upcomingMaintenance),
        background: scheme.surfaceContainerHighest,
        foreground: scheme.onSurface,
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 700 ? 4 : 2;
        return _wrapGrid(cards, c.maxWidth, cols, aspect: 1.7, spacing: 12);
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value; // null → shimmer
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.background,
    required this.foreground,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: foreground, size: 24),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      color: foreground.withValues(alpha: 0.6),
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (value == null)
                Shimmer.fromColors(
                  baseColor: foreground.withValues(alpha: 0.18),
                  highlightColor: foreground.withValues(alpha: 0.30),
                  child: Container(
                    height: 30,
                    width: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                )
              else
                Text(
                  value!,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: foreground.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActionsContent extends ConsumerWidget {
  const _QuickActionsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(currentBrandingProvider);
    final featureFlags = branding?.featureFlags ?? {};
    final roles = ref.watch(rolesProvider);
    final isManager = roles.contains('Stock Manager');
    final isStockUser = roles.contains('Stock User');
    final canAccessOps = isManager || isStockUser || roles.isEmpty;
    final hiddenActions =
        ref.watch(dashboardPrefsNotifierProvider).hiddenActions;

    final actions = <Widget>[
      if (!hiddenActions.contains('scan'))
        _ActionCard(
          icon: Icons.qr_code_scanner,
          label: context.l10n.scan,
          onTap: () => context.push('/lookup'),
        ),
      if (!hiddenActions.contains('search'))
        _ActionCard(
          icon: Icons.search,
          label: context.l10n.searchItems,
          onTap: () => context.push('/items'),
        ),
      if (!hiddenActions.contains('assets'))
        _ActionCard(
          icon: Icons.precision_manufacturing,
          label: 'Assets',
          onTap: () => context.push('/assets'),
        ),
      if (canAccessOps && !hiddenActions.contains('move_asset'))
        _ActionCard(
          icon: Icons.move_up,
          label: 'Move Asset',
          onTap: () => context.push('/asset-movement'),
        ),
      if (canAccessOps && !hiddenActions.contains('transfer'))
        _ActionCard(
          icon: Icons.swap_horiz,
          label: context.l10n.transfer,
          onTap: () => context.push('/transfer'),
        ),
      if (canAccessOps &&
          featureFlags['receipt'] != false &&
          !hiddenActions.contains('receive'))
        _ActionCard(
          icon: Icons.input,
          label: context.l10n.receive,
          onTap: () => context.push('/receipt'),
        ),
      if (canAccessOps &&
          featureFlags['reconciliation'] != false &&
          !hiddenActions.contains('count'))
        _ActionCard(
          icon: Icons.fact_check,
          label: context.l10n.count,
          onTap: () => context.push('/reconcile'),
        ),
      if (canAccessOps && !hiddenActions.contains('fulfillment'))
        _ActionCard(
          icon: Icons.local_shipping,
          label: context.l10n.fulfillment,
          onTap: () => context.push('/fulfillment'),
        ),
      if (isManager && !hiddenActions.contains('reports'))
        _ActionCard(
          icon: Icons.assessment_outlined,
          label: 'Reports',
          onTap: () => context.push('/reports'),
        ),
    ];

    if (actions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'All quick actions are hidden. Tap the customize button to restore them.',
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 700 ? 4 : (c.maxWidth >= 420 ? 3 : 2);
        return _wrapGrid(actions, c.maxWidth, cols, aspect: 1.15, spacing: 12);
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: scheme.primary),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent Activity ───────────────────────────────────────────────────────────

class _RecentActivityContent extends ConsumerWidget {
  const _RecentActivityContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opsAsync = ref.watch(allOpsProvider);
    final fmt = DateFormat.MMMd().add_jm();
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: opsAsync.when(
          loading: () => const _RecentShimmer(),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Could not load activity: $e',
              style: TextStyle(color: scheme.error),
            ),
          ),
          data: (ops) {
            if (ops.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No recent activity yet.'),
              );
            }
            final top = ([...ops]
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
                .take(5)
                .toList();
            return Column(
              children: [
                for (final op in top)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: _StatusIcon(status: op.status),
                    title: Text(op.type),
                    subtitle: Text(fmt.format(op.createdAt.toLocal())),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => context.push('/sync'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── System Status ─────────────────────────────────────────────────────────────

class _SystemStatusContent extends ConsumerWidget {
  const _SystemStatusContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final pending = ref.watch(unresolvedOpCountProvider).valueOrNull ?? 0;
    final openAlerts = ref.watch(alertCountProvider);
    final settings = ref.watch(settingsNotifierProvider);
    final auth = ref.watch(authNotifierProvider);
    final ops = ref.watch(allOpsProvider).valueOrNull ?? const [];

    final lastOp = ops.isEmpty
        ? null
        : ops.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
    final lastSync = lastOp == null
        ? '—'
        : DateFormat.MMMd().add_jm().format(lastOp.createdAt.toLocal());

    final user = auth is Authenticated
        ? (auth.session.fullName ?? auth.session.username)
        : '—';
    final warehouse = settings.defaultSourceWarehouse ?? 'Not set';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatusRow(
              icon:
                  online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              label: 'Connection',
              value: online ? 'Online' : 'Offline',
              valueColor: online ? scheme.tertiary : scheme.error,
            ),
            _StatusRow(
              icon: Icons.sync_outlined,
              label: 'Pending Sync',
              value: '$pending',
              valueColor: pending == 0 ? null : scheme.error,
            ),
            _StatusRow(
              icon: Icons.notifications_active_outlined,
              label: 'Open Alerts',
              value: '$openAlerts',
              valueColor: openAlerts == 0 ? null : scheme.error,
            ),
            _StatusRow(
              icon: Icons.schedule,
              label: 'Last Activity',
              value: lastSync,
            ),
            _StatusRow(
              icon: Icons.warehouse_outlined,
              label: 'Active Warehouse',
              value: warehouse,
            ),
            _StatusRow(
              icon: Icons.person_outline,
              label: 'User',
              value: user,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: valueColor ?? scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

Widget _wrapGrid(
  List<Widget> items,
  double maxWidth,
  int cols, {
  required double aspect,
  required double spacing,
}) {
  final itemWidth = (maxWidth - spacing * (cols - 1)) / cols;
  final itemHeight = itemWidth / aspect;
  return Wrap(
    spacing: spacing,
    runSpacing: spacing,
    children: [
      for (final item in items)
        SizedBox(width: itemWidth, height: itemHeight, child: item),
    ],
  );
}

class _RecentShimmer extends StatelessWidget {
  const _RecentShimmer();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surfaceContainerLow,
      child: Column(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  height: 14,
                  width: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final OpStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      OpStatus.pending => Icon(Icons.schedule, color: scheme.outline),
      OpStatus.pendingApproval => Icon(Icons.approval, color: scheme.primary),
      OpStatus.inflight => const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      OpStatus.failed => Icon(Icons.error, color: scheme.error),
      OpStatus.succeeded => Icon(Icons.check_circle, color: scheme.tertiary),
    };
  }
}
