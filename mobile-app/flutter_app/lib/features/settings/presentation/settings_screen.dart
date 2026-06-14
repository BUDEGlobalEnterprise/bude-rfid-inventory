import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_version.dart';
import '../../../core/ui/bude_section_header.dart';
import '../../../core/utils/locale_ext.dart';
import '../../authentication/presentation/providers/auth_notifier.dart';
import '../../tenant/presentation/providers/tenant_notifier.dart';
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

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // ── Appearance ──────────────────────────────────────────────────────
        BudeSectionHeader(context.l10n.appearance),
        _AppearanceSection(settings: settings, notifier: notifier),

        // ── Connection ──────────────────────────────────────────────────────
        BudeSectionHeader(context.l10n.connection),
        _ConnectionSection(tenant: tenant),

        // ── Defaults ────────────────────────────────────────────────────────
        BudeSectionHeader(context.l10n.defaults),
        _DefaultsSection(
          settings: settings,
          notifier: notifier,
          warehousesAsync: warehousesAsync,
        ),

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

// ═══════════════════════════════════════════════════════════════════════════════
// Scanning section
// ═══════════════════════════════════════════════════════════════════════════════

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
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.logout),
              label: Text(context.l10n.signOut),
              onPressed: () =>
                  ref.read(authNotifierProvider.notifier).logout(),
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
