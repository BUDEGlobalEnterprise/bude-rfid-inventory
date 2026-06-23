import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/providers/auth_notifier.dart';
import '../../features/tenant/presentation/providers/tenant_notifier.dart';
import 'offline_banner.dart';

/// User override for rail expansion. `null` → follow the breakpoint default
/// (extended on desktop ≥1200, collapsed on tablet).
final railExtendedProvider = StateProvider<bool?>((ref) => null);

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(rolesProvider);
    final isManager = roles.contains('Stock Manager');

    final mobileDests = _mobileDests(isManager);
    final railDests = navDests(isManager);
    final location = GoRouterState.of(context).matchedLocation;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < 600) {
          final selected = locationToIndex(location, mobileDests);
          return Scaffold(
            body: Column(
              children: [
                const OfflineBanner(),
                Expanded(child: child),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: selected,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              onDestinationSelected: (i) => context.go(mobileDests[i].route),
              destinations: [
                for (final d in mobileDests)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
          );
        }

        final override = ref.watch(railExtendedProvider);
        final extended = override ?? width >= 1200;
        final selected = locationToIndex(location, railDests);
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                extended: extended,
                selectedIndex: selected,
                onDestinationSelected: (i) => context.go(railDests[i].route),
                leading: _RailLeading(extended: extended),
                destinations: [
                  for (final d in railDests)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: Column(
                  children: [
                    const OfflineBanner(),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Mobile shows only primary destinations (NavigationBar supports max 5).
  static List<NavDest> _mobileDests(bool isManager) => [
        const NavDest(
          'Dashboard',
          Icons.dashboard_outlined,
          Icons.dashboard,
          '/',
        ),
        const NavDest('Search', Icons.search_outlined, Icons.search, '/items'),
        if (isManager) ...[
          const NavDest(
            'Warehouses',
            Icons.warehouse_outlined,
            Icons.warehouse,
            '/warehouses',
          ),
          const NavDest(
            'Analytics',
            Icons.bar_chart_outlined,
            Icons.bar_chart,
            '/analytics',
          ),
        ],
        const NavDest(
          'Settings',
          Icons.settings_outlined,
          Icons.settings,
          '/settings',
        ),
      ];
}

/// Full destination list (rail + drawer). Mobile bottom-nav uses a subset.
List<NavDest> navDests(bool isManager) => [
      const NavDest(
        'Dashboard',
        Icons.dashboard_outlined,
        Icons.dashboard,
        '/',
      ),
      const NavDest('Search', Icons.search_outlined, Icons.search, '/items'),
      const NavDest(
        'Assets',
        Icons.precision_manufacturing_outlined,
        Icons.precision_manufacturing,
        '/assets',
      ),
      if (isManager) ...[
        const NavDest(
          'Warehouses',
          Icons.warehouse_outlined,
          Icons.warehouse,
          '/warehouses',
        ),
        const NavDest(
          'Analytics',
          Icons.bar_chart_outlined,
          Icons.bar_chart,
          '/analytics',
        ),
        const NavDest(
          'Reports',
          Icons.assessment_outlined,
          Icons.assessment,
          '/reports',
        ),
      ],
      const NavDest(
        'Audit Trail',
        Icons.history_outlined,
        Icons.history,
        '/audit',
      ),
      const NavDest('Sync', Icons.sync_outlined, Icons.sync, '/sync'),
      const NavDest(
        'Settings',
        Icons.settings_outlined,
        Icons.settings,
        '/settings',
      ),
    ];

int locationToIndex(String location, List<NavDest> dests) {
  for (int i = 0; i < dests.length; i++) {
    final route = dests[i].route;
    if (route == '/' ? location == '/' : location.startsWith(route)) return i;
  }
  if (location.startsWith('/warehouse/')) {
    final i = dests.indexWhere((d) => d.route == '/warehouses');
    if (i >= 0) return i;
  }
  return 0;
}

class NavDest {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  const NavDest(this.label, this.icon, this.selectedIcon, this.route);
}

class _RailLeading extends ConsumerWidget {
  final bool extended;
  const _RailLeading({required this.extended});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment:
            extended ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          IconButton(
            tooltip: extended ? 'Collapse menu' : 'Expand menu',
            icon: Icon(extended ? Icons.menu_open : Icons.menu),
            onPressed: () =>
                ref.read(railExtendedProvider.notifier).state = !extended,
          ),
          if (extended) const _SidebarHeader(),
        ],
      ),
    );
  }
}

class _SidebarHeader extends ConsumerWidget {
  const _SidebarHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(currentBrandingProvider);
    final auth = ref.watch(authNotifierProvider);
    final companyName = branding?.companyName ?? 'Inventory';
    final userName = auth is Authenticated
        ? (auth.session.fullName ?? auth.session.username)
        : '';
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            companyName,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (userName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              userName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Navigation drawer for the mobile hamburger menu. Owned by the dashboard
/// Scaffold so the menu button appears automatically on small screens.
class AppNavDrawer extends ConsumerWidget {
  const AppNavDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(rolesProvider);
    final isManager = roles.contains('Stock Manager');
    final dests = navDests(isManager);
    final location = GoRouterState.of(context).matchedLocation;
    final selected = locationToIndex(location, dests);

    return NavigationDrawer(
      selectedIndex: selected,
      onDestinationSelected: (i) {
        Navigator.of(context).pop();
        context.go(dests[i].route);
      },
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _SidebarHeader(),
        ),
        const Divider(),
        for (final d in dests)
          NavigationDrawerDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
      ],
    );
  }
}
