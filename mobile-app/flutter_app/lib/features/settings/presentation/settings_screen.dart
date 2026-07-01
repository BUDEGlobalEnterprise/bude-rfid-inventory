import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_version.dart';
import '../../../core/ui/bude_section_header.dart';
import '../../../core/ui/navigation_config.dart';
import '../../../core/utils/locale_ext.dart';
import '../../authentication/presentation/providers/auth_notifier.dart';
import '../../navigation/data/navigation_config_remote.dart';
import '../../tenant/presentation/providers/tenant_notifier.dart';
import '../../company/presentation/providers/company_providers.dart';
import '../../transfer/presentation/providers/transfer_providers.dart';
import 'providers/settings_notifier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantState = ref.watch(tenantNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: SafeArea(
        child: switch (tenantState) {
          TenantActive(:final tenant) => _SettingsBody(tenant: tenant),
          TenantAbsent() => const _NoTenantView(),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  final dynamic tenant;
  const _SettingsBody({required this.tenant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);
    final warehousesAsync = ref.watch(warehousesProvider);
    final roles = ref.watch(rolesProvider);
    final auth = ref.watch(authNotifierProvider);
    final username = auth is Authenticated ? auth.session.username : null;
    final canConfigureNavigation = isNavigationAdmin(
      roles,
      username: username,
    );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // ── Appearance ──────────────────────────────────────────────────────
        BudeSectionHeader(context.l10n.appearance),
        _AppearanceSection(settings: settings, notifier: notifier),

        // ── Connection ──────────────────────────────────────────────────────
        BudeSectionHeader(context.l10n.connection),
        _ConnectionSection(tenant: tenant),

        // ── Company ─────────────────────────────────────────────────────────
        BudeSectionHeader(context.l10n.company),
        _CompanySection(settings: settings, notifier: notifier),

        // ── Defaults ────────────────────────────────────────────────────────
        BudeSectionHeader(context.l10n.defaults),
        _DefaultsSection(
          settings: settings,
          notifier: notifier,
          warehousesAsync: warehousesAsync,
        ),
        const BudeSectionHeader('Approval controls'),
        const _ApprovalControlsSection(),
        if (canConfigureNavigation) ...[
          const BudeSectionHeader('Navigation'),
          const _NavigationSection(),
        ],

        // ── Scanning ────────────────────────────────────────────────────────
        BudeSectionHeader(context.l10n.scanning),
        _ScanningSection(settings: settings, notifier: notifier),

        // ── Sync & Offline ──────────────────────────────────────────────────
        BudeSectionHeader(context.l10n.syncAndOffline),
        _SyncSection(settings: settings, notifier: notifier),

        // ── Diagnostics ─────────────────────────────────────────────────────
        BudeSectionHeader(context.l10n.diagnostics),
        const _DiagnosticsSection(),

        // ── Account ─────────────────────────────────────────────────────────
        BudeSectionHeader(context.l10n.account),
        _AccountSection(tenant: tenant),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Appearance section
// ═══════════════════════════════════════════════════════════════════════════════

class _AppearanceSection extends ConsumerWidget {
  final dynamic settings;
  final dynamic notifier;
  const _AppearanceSection({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsNotifierProvider);
    final n = ref.read(settingsNotifierProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Column(
        children: [
          // Theme mode picker
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.light_mode, size: 18),
                      label: Text(context.l10n.themeLight),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: const Icon(Icons.brightness_auto, size: 18),
                      label: Text(context.l10n.themeSystem),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode, size: 18),
                      label: Text(context.l10n.themeDark),
                    ),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) => n.setThemeMode(v.first),
                ),
              ],
            ),
          ),
          const Divider(height: 0),

          // Text scale
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text(context.l10n.textSize)),
                SegmentedButton<double>(
                  segments: [
                    ButtonSegment(
                      value: 1.0,
                      label: Text(context.l10n.textSizeSmall),
                    ),
                    ButtonSegment(
                      value: 1.2,
                      label: Text(context.l10n.textSizeMedium),
                    ),
                    ButtonSegment(
                      value: 1.4,
                      label: Text(context.l10n.textSizeLarge),
                    ),
                  ],
                  selected: {s.textScaleFactor},
                  onSelectionChanged: (v) => n.setTextScaleFactor(v.first),
                ),
              ],
            ),
          ),
          const Divider(height: 0),

          // High contrast
          SwitchListTile(
            title: Text(context.l10n.highContrast),
            value: s.highContrast,
            onChanged: n.setHighContrast,
          ),
          const Divider(height: 0),

          // Language
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(context.l10n.language)),
                SegmentedButton<String?>(
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('EN')),
                    ButtonSegment(value: 'ar', label: Text('عربي')),
                  ],
                  selected: {s.locale},
                  onSelectionChanged: (v) => n.setLocale(v.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Connection section
// ═══════════════════════════════════════════════════════════════════════════════

class _ConnectionSection extends StatelessWidget {
  final dynamic tenant;
  const _ConnectionSection({required this.tenant});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd();
    final branding = tenant.branding as Map<String, dynamic>?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(
              label: context.l10n.company,
              value: tenant.companyName as String,
            ),
            _InfoRow(
              label: context.l10n.erpUrl,
              value: tenant.erpUrl as String,
            ),
            _InfoRow(
              label: context.l10n.connectedSince,
              value: fmt.format((tenant.createdAt as DateTime).toLocal()),
            ),
            if (branding != null) ...[
              const Divider(height: 20),
              if (branding['erpnext_version'] != null)
                _InfoRow(
                  label: context.l10n.erpnextVersion,
                  value: branding['erpnext_version'].toString(),
                ),
              if (branding['bude_api_version'] != null)
                _InfoRow(
                  label: context.l10n.budeApiVersion,
                  value: branding['bude_api_version'].toString(),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Company section
// ═══════════════════════════════════════════════════════════════════════════════

class _CompanySection extends ConsumerWidget {
  final dynamic settings;
  final dynamic notifier;
  const _CompanySection({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsNotifierProvider);
    final n = ref.read(settingsNotifierProvider.notifier);
    final companiesAsync = ref.watch(companiesProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: companiesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => Text(context.l10n.noCompanies),
          data: (companies) => DropdownButtonFormField<String>(
            key: ValueKey('company-${s.activeCompany}'),
            decoration: InputDecoration(
              labelText: context.l10n.activeCompany,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.business),
            ),
            initialValue: s.activeCompany,
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text(context.l10n.noneSelected),
              ),
              ...companies.map(
                (c) => DropdownMenuItem(
                  value: c.name,
                  child: Text(c.companyName),
                ),
              ),
            ],
            onChanged: n.setActiveCompany,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Defaults section
// ═══════════════════════════════════════════════════════════════════════════════

class _DefaultsSection extends ConsumerWidget {
  final dynamic settings;
  final dynamic notifier;
  final AsyncValue<List<String>> warehousesAsync;
  const _DefaultsSection({
    required this.settings,
    required this.notifier,
    required this.warehousesAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsNotifierProvider);
    final n = ref.read(settingsNotifierProvider.notifier);

    final warehouses = warehousesAsync.valueOrNull ?? [];
    final noneItem = DropdownMenuItem<String>(
      value: null,
      child: Text(context.l10n.noneSelected),
    );
    final whItems = [
      noneItem,
      ...warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w))),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('src-${s.defaultSourceWarehouse}'),
              decoration: InputDecoration(
                labelText: context.l10n.defaultSourceWarehouse,
                border: const OutlineInputBorder(),
              ),
              initialValue: s.defaultSourceWarehouse,
              items: whItems,
              onChanged: n.setDefaultSourceWarehouse,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('tgt-${s.defaultTargetWarehouse}'),
              decoration: InputDecoration(
                labelText: context.l10n.defaultTargetWarehouse,
                border: const OutlineInputBorder(),
              ),
              initialValue: s.defaultTargetWarehouse,
              items: whItems,
              onChanged: n.setDefaultTargetWarehouse,
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalControlsSection extends ConsumerWidget {
  const _ApprovalControlsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              decoration: InputDecoration(
                labelText: context.l10n.varianceThreshold,
                hintText: context.l10n.varianceThresholdHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.warning_amber_outlined),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              initialValue: settings.reconciliationVarianceThreshold == 0.0
                  ? ''
                  : settings.reconciliationVarianceThreshold.toString(),
              onChanged: (v) {
                final parsed = double.tryParse(v);
                notifier.setReconciliationVarianceThreshold(parsed ?? 0.0);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Transfer approval threshold (qty)',
                hintText: '0 disables transfer approval',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.approval_outlined),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              initialValue: settings.transferApprovalQtyThreshold == 0.0
                  ? ''
                  : settings.transferApprovalQtyThreshold.toString(),
              onChanged: (v) {
                final parsed = double.tryParse(v);
                notifier.setTransferApprovalQtyThreshold(parsed ?? 0.0);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Receipt rejected-qty approval threshold',
                hintText: '0 disables receipt-rejection approval',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.report_problem_outlined),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              initialValue:
                  settings.receiptRejectedQtyApprovalThreshold == 0.0
                      ? ''
                      : settings.receiptRejectedQtyApprovalThreshold
                          .toString(),
              onChanged: (v) {
                final parsed = double.tryParse(v);
                notifier.setReceiptRejectedQtyApprovalThreshold(parsed ?? 0.0);
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Transfers above the quantity threshold, counts above the '
              'variance threshold, and receipts with rejected quantity above '
              'their threshold queue for Stock Manager approval.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Scanning section
// ═══════════════════════════════════════════════════════════════════════════════

/// Admin-only editor for the per-role sidebar config. Visibility is per role
/// bucket; order is shared across roles. Saves to the backend, then refreshes
/// branding so the new config applies immediately.
class _NavigationSection extends ConsumerStatefulWidget {
  const _NavigationSection();

  @override
  ConsumerState<_NavigationSection> createState() => _NavigationSectionState();
}

class _NavigationSectionState extends ConsumerState<_NavigationSection> {
  late List<String> _order;
  late Map<String, Set<String>> _hiddenByBucket;
  String _bucket = navigationRoleBuckets.first;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _loadFromConfig(ref.read(currentBrandingProvider)?.navigation);
  }

  void _loadFromConfig(Map<String, dynamic>? nav) {
    final saved = resolveNavOrder(nav) ?? const <String>[];
    final known = allNavigationDestinations.map((d) => d.id).toList();
    _order = [
      ...saved.where(known.contains),
      ...known.where((id) => !saved.contains(id)),
    ];
    _hiddenByBucket = {
      for (final b in navigationRoleBuckets)
        b: resolveNavHidden(nav, _rolesForBucket(b)),
    };
  }

  Set<String> _rolesForBucket(String bucket) => switch (bucket) {
        'Stock Manager' => {'Stock Manager'},
        'Stock User' => {'Stock User'},
        _ => <String>{},
      };

  Map<String, dynamic> _toConfig() => {
        'order': _order,
        'buckets': {
          for (final b in navigationRoleBuckets)
            b: {'hidden': _hiddenByBucket[b]!.toList()..sort()},
        },
      };

  void _toggle(String id, bool visible) {
    setState(() {
      final set = _hiddenByBucket[_bucket]!;
      if (visible) {
        set.remove(id);
      } else {
        set.add(id);
      }
      _dirty = true;
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    // onReorderItem already adjusts newIndex for the removed item.
    setState(() {
      final id = _order.removeAt(oldIndex);
      _order.insert(newIndex, id);
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(navigationConfigRemoteProvider).save(_toConfig());
      await ref.read(tenantNotifierProvider.notifier).refreshBranding();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Navigation saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hidden = _hiddenByBucket[_bucket]!;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              'Order is shared across roles; visibility is per role.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<String>(
              segments: [
                for (final b in navigationRoleBuckets)
                  ButtonSegment(value: b, label: Text(b)),
              ],
              selected: {_bucket},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _bucket = v.first),
            ),
          ),
          const Divider(height: 0),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: _reorder,
            children: [
              for (var i = 0; i < _order.length; i++)
                _buildRow(_order[i], i, hidden),
            ],
          ),
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.restore),
                  label: const Text('Show all'),
                  onPressed: hidden.isEmpty
                      ? null
                      : () => setState(() {
                            hidden.clear();
                            _dirty = true;
                          }),
                ),
                const Spacer(),
                FilledButton.icon(
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                  onPressed: (_dirty && !_saving) ? _save : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String id, int index, Set<String> hidden) {
    final dest = allNavigationDestinations.firstWhere((d) => d.id == id);
    final visible = dest.mandatory || !hidden.contains(id);
    return ListTile(
      key: ValueKey(id),
      contentPadding: const EdgeInsets.only(left: 16, right: 8),
      leading: Switch(
        value: visible,
        onChanged: dest.mandatory ? null : (v) => _toggle(id, v),
      ),
      title: Text(dest.label),
      subtitle: Text(dest.route),
      trailing: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle),
      ),
    );
  }
}

class _ScanningSection extends ConsumerWidget {
  final dynamic settings;
  final dynamic notifier;
  const _ScanningSection({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsNotifierProvider);
    final n = ref.read(settingsNotifierProvider.notifier);
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: Text(context.l10n.scanSound),
            value: s.scanSound,
            onChanged: n.setScanSound,
          ),
          const Divider(height: 0),
          SwitchListTile(
            title: Text(context.l10n.scanVibration),
            value: s.scanVibration,
            onChanged: n.setScanVibration,
          ),
          const Divider(height: 0),
          SwitchListTile(
            title: Text(context.l10n.continuousScanMode),
            value: s.continuousScanMode,
            onChanged: n.setContinuousScanMode,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sync & Offline section
// ═══════════════════════════════════════════════════════════════════════════════

class _SyncSection extends ConsumerWidget {
  final dynamic settings;
  final dynamic notifier;
  const _SyncSection({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsNotifierProvider);
    final n = ref.read(settingsNotifierProvider.notifier);
    return Card(
      child: Column(
        children: [
          // Sync interval picker
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text(context.l10n.syncInterval)),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 15, label: Text('15')),
                    ButtonSegment(value: 30, label: Text('30')),
                    ButtonSegment(value: 60, label: Text('60')),
                  ],
                  selected: {s.syncIntervalMinutes},
                  onSelectionChanged: (v) => n.setSyncIntervalMinutes(v.first),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          SwitchListTile(
            title: Text(context.l10n.wifiOnlySync),
            value: s.syncOnWifiOnly,
            onChanged: n.setSyncOnWifiOnly,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Diagnostics section
// ═══════════════════════════════════════════════════════════════════════════════

class _DiagnosticsSection extends StatelessWidget {
  const _DiagnosticsSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(
              label: context.l10n.appVersion,
              value: AppVersion.footer,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Account section
// ═══════════════════════════════════════════════════════════════════════════════

class _AccountSection extends ConsumerWidget {
  final dynamic tenant;
  const _AccountSection({required this.tenant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsNotifierProvider);
    final n = ref.read(settingsNotifierProvider.notifier);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.autoLogout,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: 0,
                      label: Text(context.l10n.autoLogoutDisabled),
                    ),
                    const ButtonSegment(value: 5, label: Text('5 min')),
                    const ButtonSegment(value: 15, label: Text('15 min')),
                    const ButtonSegment(value: 30, label: Text('30 min')),
                  ],
                  selected: {s.autoLogoutMinutes},
                  onSelectionChanged: (v) => n.setAutoLogoutMinutes(v.first),
                  showSelectedIcon: false,
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.logout),
              label: Text(context.l10n.signOut),
              onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: OutlinedButton.icon(
              icon: Icon(
                Icons.link_off,
                color: Theme.of(context).colorScheme.error,
              ),
              label: Text(
                context.l10n.resetConnection,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              onPressed: () => _confirmReset(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.resetConnectionTitle),
        content: Text(context.l10n.resetConnectionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.reset),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(authNotifierProvider.notifier).logout();
    await ref.read(tenantNotifierProvider.notifier).clearActive();
    if (!context.mounted) return;
    context.go('/onboarding');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// No-tenant fallback
// ═══════════════════════════════════════════════════════════════════════════════

class _NoTenantView extends StatelessWidget {
  const _NoTenantView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.noConnectionConfigured),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => GoRouter.of(context).go('/onboarding'),
              child: Text(context.l10n.setUpNow),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared helpers
// ═══════════════════════════════════════════════════════════════════════════════

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
