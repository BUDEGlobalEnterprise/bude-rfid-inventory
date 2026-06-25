import 'package:flutter/material.dart';

class NavDest {
  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  final bool managerOnly;
  final bool operationsOnly;
  final bool mandatory;
  final bool mobilePrimary;

  const NavDest({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
    this.managerOnly = false,
    this.operationsOnly = false,
    this.mandatory = false,
    this.mobilePrimary = false,
  });
}

const allNavigationDestinations = <NavDest>[
  NavDest(
    id: 'dashboard',
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    route: '/',
    mandatory: true,
    mobilePrimary: true,
  ),
  NavDest(
    id: 'search',
    label: 'Search',
    icon: Icons.search_outlined,
    selectedIcon: Icons.search,
    route: '/items',
    mobilePrimary: true,
  ),
  NavDest(
    id: 'lookup',
    label: 'Lookup',
    icon: Icons.qr_code_scanner_outlined,
    selectedIcon: Icons.qr_code_scanner,
    route: '/lookup',
    mobilePrimary: true,
  ),
  NavDest(
    id: 'transfer',
    label: 'Transfer',
    icon: Icons.swap_horiz_outlined,
    selectedIcon: Icons.swap_horiz,
    route: '/transfer',
    operationsOnly: true,
  ),
  NavDest(
    id: 'receipt',
    label: 'Receive',
    icon: Icons.input_outlined,
    selectedIcon: Icons.input,
    route: '/receipt',
    operationsOnly: true,
  ),
  NavDest(
    id: 'count',
    label: 'Count',
    icon: Icons.fact_check_outlined,
    selectedIcon: Icons.fact_check,
    route: '/reconcile',
    operationsOnly: true,
  ),
  NavDest(
    id: 'assets',
    label: 'Assets',
    icon: Icons.precision_manufacturing_outlined,
    selectedIcon: Icons.precision_manufacturing,
    route: '/assets',
  ),
  NavDest(
    id: 'asset_movement',
    label: 'Move Asset',
    icon: Icons.move_up_outlined,
    selectedIcon: Icons.move_up,
    route: '/asset-movement',
    operationsOnly: true,
  ),
  NavDest(
    id: 'asset_repair',
    label: 'Repair Asset',
    icon: Icons.build_circle_outlined,
    selectedIcon: Icons.build_circle,
    route: '/asset-repair',
    operationsOnly: true,
  ),
  NavDest(
    id: 'warehouses',
    label: 'Warehouses',
    icon: Icons.warehouse_outlined,
    selectedIcon: Icons.warehouse,
    route: '/warehouses',
    managerOnly: true,
    mobilePrimary: true,
  ),
  NavDest(
    id: 'masters',
    label: 'Master Data',
    icon: Icons.category_outlined,
    selectedIcon: Icons.category,
    route: '/masters',
    managerOnly: true,
  ),
  NavDest(
    id: 'analytics',
    label: 'Analytics',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
    route: '/analytics',
    managerOnly: true,
    mobilePrimary: true,
  ),
  NavDest(
    id: 'stock_aging',
    label: 'Stock Aging',
    icon: Icons.hourglass_bottom_outlined,
    selectedIcon: Icons.hourglass_bottom,
    route: '/analytics/aging',
    managerOnly: true,
  ),
  NavDest(
    id: 'variance',
    label: 'Variance',
    icon: Icons.difference_outlined,
    selectedIcon: Icons.difference,
    route: '/analytics/variance',
    managerOnly: true,
  ),
  NavDest(
    id: 'throughput',
    label: 'Throughput',
    icon: Icons.timeline_outlined,
    selectedIcon: Icons.timeline,
    route: '/analytics/throughput',
    managerOnly: true,
  ),
  NavDest(
    id: 'export',
    label: 'Export',
    icon: Icons.file_download_outlined,
    selectedIcon: Icons.file_download,
    route: '/analytics/export',
    managerOnly: true,
  ),
  NavDest(
    id: 'alerts',
    label: 'Alerts',
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
    route: '/alerts',
  ),
  NavDest(
    id: 'reports',
    label: 'Reports',
    icon: Icons.assessment_outlined,
    selectedIcon: Icons.assessment,
    route: '/reports',
    managerOnly: true,
  ),
  NavDest(
    id: 'audit',
    label: 'Audit Trail',
    icon: Icons.history_outlined,
    selectedIcon: Icons.history,
    route: '/audit',
  ),
  NavDest(
    id: 'sync',
    label: 'Sync',
    icon: Icons.sync_outlined,
    selectedIcon: Icons.sync,
    route: '/sync',
  ),
  NavDest(
    id: 'settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    route: '/settings',
    mandatory: true,
    mobilePrimary: true,
  ),
];

bool isNavigationAdmin(Set<String> roles, {String? username}) {
  return username == 'Administrator' ||
      roles.contains('Administrator') ||
      roles.contains('System Manager');
}

bool canAccessManagerDestinations(Set<String> roles, {String? username}) {
  return isNavigationAdmin(roles, username: username) ||
      roles.contains('Stock Manager');
}

/// Role tiers an admin can configure visibility for. A user is mapped to
/// exactly one (highest-priority first) via [navigationBucketFor].
const navigationRoleBuckets = <String>[
  'Stock Manager',
  'Stock User',
  'Default'
];

/// The single config bucket a user falls into, by role priority.
String navigationBucketFor(Set<String> roles, {String? username}) {
  if (canAccessManagerDestinations(roles, username: username)) {
    return 'Stock Manager';
  }
  if (roles.contains('Stock User')) return 'Stock User';
  return 'Default';
}

/// Hidden destination ids for the given user, read from the admin-configured
/// per-role navigation config (shape: `{buckets: {role: {hidden: [...]}}}`).
/// Null/missing config → nothing hidden. Mandatory destinations are still
/// force-shown later by [navigationDestsFor].
Set<String> resolveNavHidden(
  Map<String, dynamic>? navigation,
  Set<String> roles, {
  String? username,
}) {
  if (navigation == null) return const {};
  final buckets = navigation['buckets'];
  if (buckets is! Map) return const {};
  final bucket = buckets[navigationBucketFor(roles, username: username)];
  if (bucket is! Map) return const {};
  final hidden = bucket['hidden'];
  if (hidden is! List) return const {};
  return hidden.whereType<String>().toSet();
}

/// The shared destination ordering (ids) from config, or null for default.
List<String>? resolveNavOrder(Map<String, dynamic>? navigation) {
  if (navigation == null) return null;
  final order = navigation['order'];
  if (order is! List) return null;
  final ids = order.whereType<String>().toList();
  return ids.isEmpty ? null : ids;
}

/// Stable-sort [dests] by [order] (ids). Unlisted destinations keep their
/// relative position after the ordered ones.
List<NavDest> _applyOrder(List<NavDest> dests, List<String>? order) {
  if (order == null || order.isEmpty) return dests;
  final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
  final indexed = dests.asMap().entries.toList();
  indexed.sort((a, b) {
    final ra = rank[a.value.id] ?? (order.length + a.key);
    final rb = rank[b.value.id] ?? (order.length + b.key);
    return ra.compareTo(rb);
  });
  return [for (final e in indexed) e.value];
}

bool _canUseDestination(NavDest dest, Set<String> roles, {String? username}) {
  final isManager = canAccessManagerDestinations(roles, username: username);
  final isStockUser = roles.contains('Stock User');
  final canUseOps = isManager || isStockUser || roles.isEmpty;

  if (dest.managerOnly && !isManager) return false;
  if (dest.operationsOnly && !canUseOps) return false;
  return true;
}

List<NavDest> navigationDestsFor({
  required Set<String> roles,
  required Iterable<String> hiddenIds,
  List<String>? order,
  bool mobile = false,
  String? username,
}) {
  final hidden = hiddenIds.toSet();
  final filtered = allNavigationDestinations.where((dest) {
    if (!_canUseDestination(dest, roles, username: username)) return false;
    if (dest.mandatory) return true;
    return !hidden.contains(dest.id);
  }).toList();
  final eligible = _applyOrder(filtered, order);

  if (!mobile) return eligible;

  final settings =
      eligible.where((dest) => dest.id == 'settings').toList(growable: false);
  final primary = eligible
      .where((dest) => dest.mobilePrimary && dest.id != 'settings')
      .take(4)
      .toList();
  return [...primary, ...settings];
}

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
