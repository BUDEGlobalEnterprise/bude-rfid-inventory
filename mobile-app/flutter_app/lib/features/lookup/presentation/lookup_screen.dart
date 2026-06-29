import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/hardware/adapters/hardware_exceptions.dart';
import '../../../core/hardware/entities/scan_event.dart';
import '../../../core/hardware/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/error_banner.dart';
import '../../../core/ui/loading_shimmer.dart';
import '../../../core/ui/operational_components.dart';
import '../../../core/utils/locale_ext.dart';
import '../data/epc_remote_data_source.dart';
import 'providers/lookup_notifier.dart';
import 'providers/lookup_providers.dart';

/// Scan-to-locate: resolve an RFID EPC (or barcode) to an asset / item /
/// serial and route to its detail. Full-screen task flow (outside the shell).
class LookupScreen extends ConsumerStatefulWidget {
  const LookupScreen({super.key});

  @override
  ConsumerState<LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends ConsumerState<LookupScreen> {
  final _epcCtrl = TextEditingController();
  String? _hardwareError;

  @override
  void dispose() {
    _epcCtrl.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _scanBarcode() async {
    final ev = await context.push<ScanEvent>('/scan');
    if (ev == null || !mounted) return;
    _epcCtrl.text = ev.barcode;
    _clearHardwareError();
    ref.read(lookupNotifierProvider.notifier).resolve(ev.barcode);
  }

  Future<void> _readRfid() async {
    final rfid = ref.read(rfidAdapterProvider);
    if (rfid == null) {
      setState(() => _hardwareError = context.l10n.noRfidReader);
      return;
    }

    _clearHardwareError();
    try {
      if (!rfid.isConnected) await rfid.connect();
      final tag = await rfid.readTag();
      if (!mounted) return;
      if (tag == null || tag.epc.isEmpty) {
        setState(() => _hardwareError = context.l10n.noTagRead);
        return;
      }
      _epcCtrl.text = tag.epc;
      ref.read(lookupNotifierProvider.notifier).resolve(tag.epc);
    } on VendorSdkUnavailableException catch (e) {
      if (!mounted) return;
      setState(() => _hardwareError = e.toString());
    } on HardwareOperationException catch (e) {
      if (!mounted) return;
      setState(() => _hardwareError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _hardwareError = '$e');
    }
  }

  void _resolve() {
    final query = _epcCtrl.text.trim();
    if (query.isEmpty) return;
    _clearHardwareError();
    ref.read(lookupNotifierProvider.notifier).resolve(query);
  }

  void _retry(String query) {
    _epcCtrl.text = query;
    _clearHardwareError();
    ref.read(lookupNotifierProvider.notifier).resolve(query);
  }

  void _clearHardwareError() {
    if (_hardwareError != null) setState(() => _hardwareError = null);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lookupNotifierProvider);
    final rfid = ref.watch(rfidAdapterProvider);
    final hasRfid = rfid != null;
    final isDemoRfid = rfid?.vendor == 'demo';
    final isLoading = state is LookupResolving;
    final l10n = context.l10n;

    // Haptic feedback on successful match
    ref.listen<LookupState>(lookupNotifierProvider, (prev, next) {
      if (next is LookupResolved && !next.match.isUnregistered) {
        HapticFeedback.mediumImpact();
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lookupTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // ── Demo RFID banner ──────────────────────────────────────────
          if (isDemoRfid) ...[
            _DemoRfidBanner(),
            const SizedBox(height: AppSpacing.sm + 4),
          ],

          // ── Input field ───────────────────────────────────────────────
          TextField(
            controller: _epcCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.lookupInputLabel,
              hintText: l10n.lookupInputHint,
              prefixIcon: const Icon(Icons.nfc),
              border: const OutlineInputBorder(),
              suffixIcon: _epcCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _epcCtrl.clear();
                        ref.read(lookupNotifierProvider.notifier).clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _resolve(),
          ),
          const SizedBox(height: AppSpacing.sm + 4),

          // ── Action buttons ────────────────────────────────────────────
          Wrap(
            spacing: AppSpacing.sm + 4,
            runSpacing: AppSpacing.sm,
            children: [
              if (hasRfid)
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _readRfid,
                  icon: const Icon(Icons.nfc),
                  label: Text(l10n.readRfid),
                ),
              OutlinedButton.icon(
                onPressed: isLoading ? null : _scanBarcode,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(hasRfid ? l10n.scanBarcode : l10n.scan),
              ),
              FilledButton.icon(
                onPressed: isLoading ? null : _resolve,
                icon: const Icon(Icons.search),
                label: Text(l10n.resolveAction),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Hardware error (reader / camera failures) ─────────────────
          if (_hardwareError != null) ...[
            ErrorBanner(message: _hardwareError!),
            const SizedBox(height: AppSpacing.sm),
          ],

          // ── State-driven content ──────────────────────────────────────
          _buildContent(state),
        ],
      ),
    );
  }

  Widget _buildContent(LookupState state) {
    final l10n = context.l10n;
    return switch (state) {
      LookupIdle() => const SizedBox.shrink(),
      LookupResolving(:final query) => _ResolvingView(query: query),
      LookupResolved(:final match, :final query) =>
        _ResolvedView(match: match, query: query),
      LookupError(:final message, :final query, :final isOffline) =>
        _ErrorView(
          message: isOffline ? l10n.lookupNetworkError : message,
          isOffline: isOffline,
          onRetry: () => _retry(query),
        ),
    };
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Private widgets
// ──────────────────────────────────────────────────────────────────────────────

class _DemoRfidBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        child: Row(
          children: [
            Icon(Icons.sensors, color: scheme.onSecondaryContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.lookupDemoBanner,
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder while resolving.
class _ResolvingView extends StatelessWidget {
  final String query;
  const _ResolvingView({required this.query});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Text(
                context.l10n.lookupResolving,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const ShimmerList(count: 1),
      ],
    );
  }
}

/// Error view with retry.
class _ErrorView extends StatelessWidget {
  final String message;
  final bool isOffline;
  final VoidCallback onRetry;
  const _ErrorView({
    required this.message,
    required this.isOffline,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ErrorBanner(
          message: message,
          icon: isOffline ? Icons.cloud_off : Icons.error_outline,
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.retry),
          ),
        ),
      ],
    );
  }
}

/// Shows the resolved result — a matched record or an unregistered bind card.
class _ResolvedView extends StatelessWidget {
  final ScanMatch match;
  final String query;
  const _ResolvedView({required this.match, required this.query});

  @override
  Widget build(BuildContext context) {
    return switch (match.matchType) {
      'asset' => _AssetMatchCard(asset: match.asset!, query: query),
      'item' => _ItemMatchCard(item: match.item!, query: query),
      'serial' => _SerialMatchCard(serial: match.serial!, query: query),
      _ => _BindCard(query: query),
    };
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Match cards — design-system aligned
// ──────────────────────────────────────────────────────────────────────────────

class _AssetMatchCard extends StatelessWidget {
  final Map<String, dynamic> asset;
  final String query;
  const _AssetMatchCard({required this.asset, required this.query});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final name = (asset['asset_name'] ?? asset['name'] ?? '').toString();
    final assetId = (asset['name'] ?? '').toString();
    final status = (asset['status'] ?? '—').toString();
    final location = (asset['location'] ?? '—').toString();
    final custodian = (asset['custodian'] ?? '—').toString();

    return _MatchCardShell(
      icon: Icons.precision_manufacturing,
      title: name,
      subtitle: assetId,
      chips: [
        BudeStatusChip(
          label: status,
          icon: Icons.circle,
          color: _statusColor(status, scheme),
        ),
        if (location != '—')
          BudeStatusChip(
            label: location,
            icon: Icons.location_on_outlined,
            color: scheme.tertiary,
          ),
      ],
      details: [
        _DetailRow(label: l10n.statusLabel, value: status),
        _DetailRow(label: l10n.locationLabel, value: location),
        _DetailRow(label: l10n.custodianLabel, value: custodian),
      ],
      actionLabel: l10n.openAsset,
      onAction: () => context.push(
        '/assets/${Uri.encodeComponent(assetId)}',
      ),
    );
  }

  Color _statusColor(String status, ColorScheme scheme) {
    return switch (status.toLowerCase()) {
      'submitted' || 'in use' => scheme.primary,
      'scrapped' || 'sold' => scheme.error,
      _ => scheme.tertiary,
    };
  }
}

class _ItemMatchCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String query;
  const _ItemMatchCard({required this.item, required this.query});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final itemName = (item['item_name'] ?? item['item_code'] ?? '').toString();
    final itemCode = (item['item_code'] ?? '').toString();

    return _MatchCardShell(
      icon: Icons.inventory_2,
      title: itemName,
      subtitle: itemCode,
      chips: [
        BudeStatusChip(
          label: itemCode,
          icon: Icons.qr_code,
          color: scheme.primary,
        ),
      ],
      details: [
        _DetailRow(label: l10n.itemCode, value: itemCode),
      ],
      actionLabel: l10n.openItem,
      onAction: () => context.push(
        '/items/${Uri.encodeComponent(itemCode)}',
      ),
    );
  }
}

class _SerialMatchCard extends StatelessWidget {
  final Map<String, dynamic> serial;
  final String query;
  const _SerialMatchCard({required this.serial, required this.query});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final serialName = (serial['name'] ?? '').toString();
    final itemName =
        (serial['item_name'] ?? serial['item_code'] ?? '—').toString();
    final status = (serial['status'] ?? '—').toString();
    final itemCode = (serial['item_code'] ?? '').toString();

    return _MatchCardShell(
      icon: Icons.qr_code_2,
      title: serialName,
      subtitle: itemName,
      chips: [
        BudeStatusChip(
          label: status,
          icon: Icons.circle,
          color: _serialStatusColor(status, scheme),
        ),
      ],
      details: [
        _DetailRow(label: l10n.itemCode, value: itemName),
        _DetailRow(label: l10n.statusLabel, value: status),
      ],
      actionLabel: l10n.openItem,
      onAction: () => context.push(
        '/items/${Uri.encodeComponent(itemCode)}',
      ),
    );
  }

  Color _serialStatusColor(String status, ColorScheme scheme) {
    return switch (status.toLowerCase()) {
      'active' => scheme.primary,
      'inactive' || 'expired' => scheme.error,
      _ => scheme.tertiary,
    };
  }
}

/// Unified match card layout with design system tokens.
class _MatchCardShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> chips;
  final List<Widget> details;
  final String actionLabel;
  final VoidCallback onAction;

  const _MatchCardShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.details,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Status chips
            if (chips.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm + 4),
              Wrap(spacing: 6, runSpacing: 6, children: chips),
            ],

            // Detail rows
            if (details.isNotEmpty) ...[
              const Divider(height: AppSpacing.lg + 8),
              ...details,
            ],

            // Action button
            const SizedBox(height: AppSpacing.sm + 4),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Bind card — for unregistered tags
// ──────────────────────────────────────────────────────────────────────────────

/// Shown when the EPC isn't registered — bind it to a record by name.
class _BindCard extends ConsumerStatefulWidget {
  final String query;
  const _BindCard({required this.query});

  @override
  ConsumerState<_BindCard> createState() => _BindCardState();
}

class _BindCardState extends ConsumerState<_BindCard> {
  String _doctype = 'Asset';
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.link_off, color: scheme.onErrorContainer),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Text(
                  l10n.tagNotRegistered,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.bindEpcDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            DropdownButtonFormField<String>(
              value: _doctype,
              decoration: InputDecoration(
                labelText: l10n.recordType,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'Asset',
                  child: Text(l10n.assetLabel),
                ),
                DropdownMenuItem(
                  value: 'Item',
                  child: Text(l10n.openItem),
                ),
                DropdownMenuItem(
                  value: 'Serial No',
                  child: Text(l10n.serialNoLabel),
                ),
              ],
              onChanged: (v) => setState(() => _doctype = v ?? 'Asset'),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: _doctype == 'Item'
                    ? l10n.itemCode
                    : l10n.recordName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () {
                  ref.read(lookupNotifierProvider.notifier).bind(
                        widget.query,
                        _doctype,
                        _nameCtrl.text,
                      );
                },
                icon: const Icon(Icons.link),
                label: Text(l10n.bindEpc),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
