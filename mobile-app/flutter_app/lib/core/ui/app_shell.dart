import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/providers/auth_notifier.dart';
import '../../features/company/domain/entities/company.dart';
import '../../features/company/presentation/providers/company_providers.dart';
import '../../features/settings/presentation/providers/settings_notifier.dart';
import '../../features/tenant/presentation/providers/tenant_notifier.dart';
import 'navigation_config.dart';
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
    final auth = ref.watch(authNotifierProvider);
    final username = auth is Authenticated ? auth.session.username : null;
    final nav = ref.watch(currentBrandingProvider)?.navigation;
    final hidden = resolveNavHidden(nav, roles, username: username);
    final order = resolveNavOrder(nav);

    final mobileDests = navigationDestsFor(
      roles: roles,
      hiddenIds: hidden,
      order: order,
      mobile: true,
      username: username,
    );
    final railDests = navigationDestsFor(
      roles: roles,
      hiddenIds: hidden,
      order: order,
      username: username,
    );
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
                const _CompanyBanner(),
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
                    const _CompanyBanner(),
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
}

/// Active-company chip shown above content. Tap opens a switcher sheet.
/// Hidden when fewer than two companies exist (nothing to switch).
class _CompanyBanner extends ConsumerWidget {
  const _CompanyBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companies = ref.watch(companiesProvider).valueOrNull ?? const [];
    if (companies.length < 2) return const SizedBox.shrink();

    final active = ref.watch(
      settingsNotifierProvider.select((s) => s.activeCompany),
    );
    final scheme = Theme.of(context).colorScheme;
    final label = active == null
        ? 'Select company'
        : companies
            .firstWhere(
              (c) => c.name == active,
              orElse: () => companies.first,
            )
            .companyName;

    return Material(
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => _showSwitcher(context, ref, companies, active),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.business_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.unfold_more, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  void _showSwitcher(
    BuildContext context,
    WidgetRef ref,
    List<Company> companies,
    String? active,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in companies)
              ListTile(
                title: Text(c.companyName),
                trailing: c.name == active ? const Icon(Icons.check) : null,
                onTap: () {
                  ref
                      .read(settingsNotifierProvider.notifier)
                      .setActiveCompany(c.name);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
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
    final auth = ref.watch(authNotifierProvider);
    final username = auth is Authenticated ? auth.session.username : null;
    final nav = ref.watch(currentBrandingProvider)?.navigation;
    final dests = navigationDestsFor(
      roles: roles,
      hiddenIds: resolveNavHidden(nav, roles, username: username),
      order: resolveNavOrder(nav),
      username: username,
    );
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
