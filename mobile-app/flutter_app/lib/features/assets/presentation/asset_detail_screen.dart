import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/providers.dart';
import '../data/asset_op_submitters.dart';
import '../data/asset_remote_data_source.dart';
import 'providers/asset_providers.dart';

class AssetDetailScreen extends ConsumerWidget {
  final String assetName;
  const AssetDetailScreen({super.key, required this.assetName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(assetDetailProvider(assetName));

    return Scaffold(
      appBar: AppBar(title: const Text('Asset')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child:
                Text('Failed to load asset: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (a) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(assetDetailProvider(assetName));
            ref.invalidate(assetMovementsProvider(assetName));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                a.assetName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                a.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              _InfoCard(asset: a),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => context.push(
                      '/asset-movement?asset=${Uri.encodeComponent(a.name)}',
                    ),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Move'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.push(
                      '/asset-repair?asset=${Uri.encodeComponent(a.name)}',
                    ),
                    icon: const Icon(Icons.build),
                    label: const Text('Report repair'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (a.depreciationSchedule.isNotEmpty) ...[
                const _SectionHeader('Depreciation'),
                _DepreciationCard(rows: a.depreciationSchedule),
                const SizedBox(height: 16),
              ],
              const _SectionHeader('Maintenance'),
              _MaintenanceSection(asset: a.name),
              const SizedBox(height: 16),
              const _SectionHeader('Movement history'),
              _MovementHistory(asset: a.name),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final AssetDetail asset;
  const _InfoCard({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(context, 'Status', asset.status ?? '—'),
            _row(context, 'Category', asset.category ?? '—'),
            _row(context, 'Location', asset.location ?? '—'),
            _row(
              context,
              'Custodian',
              asset.custodianName ?? asset.custodian ?? '—',
            ),
            _row(
              context,
              'Purchase date',
              asset.purchaseDate.isEmpty ? '—' : asset.purchaseDate,
            ),
            _row(context, 'Gross amount', _money(asset.grossPurchaseAmount)),
            _row(
              context,
              'Current value',
              _money(asset.valueAfterDepreciation),
            ),
            if (asset.epc != null) _row(context, 'RFID EPC', asset.epc!),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _money(num? v) => v == null ? '—' : v.toStringAsFixed(2);
}

class _DepreciationCard extends StatelessWidget {
  final List<DepreciationRow> rows;
  const _DepreciationCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (final r in rows)
            ListTile(
              dense: true,
              leading: const Icon(Icons.trending_down, size: 20),
              title: Text(r.scheduleDate),
              subtitle: r.accumulated == null
                  ? null
                  : Text('Accumulated: ${r.accumulated!.toStringAsFixed(2)}'),
              trailing: Text(
                r.depreciationAmount?.toStringAsFixed(2) ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _MovementHistory extends ConsumerWidget {
  final String asset;
  const _MovementHistory({required this.asset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movesAsync = ref.watch(assetMovementsProvider(asset));
    return movesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Could not load movements: $e'),
      ),
      data: (moves) {
        if (moves.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No movement history'),
          );
        }
        return Card(
          child: Column(
            children: [
              for (final m in moves)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.swap_horiz, size: 20),
                  title: Text(m.purpose ?? 'Movement'),
                  subtitle: Text(
                    '${m.sourceLocation ?? '—'} → ${m.targetLocation ?? '—'}'
                    '${m.transactionDate.isNotEmpty ? '  ·  ${m.transactionDate}' : ''}',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MaintenanceSection extends ConsumerWidget {
  final String asset;
  const _MaintenanceSection({required this.asset});

  Future<void> _complete(WidgetRef ref, String log) async {
    await ref
        .read(syncQueueProvider)
        .enqueue(type: kMaintenanceLogOpType, payload: {'log': log});
    await ref.read(syncEngineProvider).kick();
    ref.invalidate(assetMaintenanceLogsProvider(asset));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(assetMaintenanceLogsProvider(asset));
    return logsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Could not load maintenance: $e'),
      ),
      data: (logs) {
        if (logs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No scheduled maintenance'),
          );
        }
        return Card(
          child: Column(
            children: [
              for (final l in logs)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.engineering, size: 20),
                  title: Text(l.task ?? 'Maintenance task'),
                  subtitle: Text(
                    'Due: ${l.dueDate.isEmpty ? '—' : l.dueDate}',
                  ),
                  trailing: TextButton(
                    onPressed: () => _complete(ref, l.name),
                    child: const Text('Complete'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
