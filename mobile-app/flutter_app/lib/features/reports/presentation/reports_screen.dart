import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/reports_remote_data_source.dart';
import 'providers/reports_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Asset Reports'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Register'),
              Tab(text: 'Maintenance'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_RegisterTab(), _MaintenanceTab()],
        ),
      ),
    );
  }
}

class _RegisterTab extends ConsumerWidget {
  const _RegisterTab();

  Future<void> _exportCsv(
    BuildContext context,
    List<Map<String, dynamic>> rows,
  ) async {
    final csvRows = <List<dynamic>>[
      [
        'Asset',
        'Name',
        'Category',
        'Location',
        'Status',
        'Purchase Date',
        'Gross Amount',
        'Current Value',
      ],
      for (final r in rows)
        [
          r['name'],
          r['asset_name'] ?? '',
          r['asset_category'] ?? '',
          r['location'] ?? '',
          r['status'] ?? '',
          r['purchase_date'] ?? '',
          r['gross_purchase_amount'] ?? '',
          r['value_after_depreciation'] ?? '',
        ],
    ];
    final csv = const ListToCsvConverter().convert(csvRows);
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/asset_register_$ts.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Asset Register',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registerAsync = ref.watch(assetRegisterProvider);
    return registerAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load register: $e'),
        ),
      ),
      data: (rows) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text('${rows.length} assets'),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed:
                      rows.isEmpty ? null : () => _exportCsv(context, rows),
                  icon: const Icon(Icons.download),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, i) {
                final r = rows[i];
                return ListTile(
                  dense: true,
                  title: Text((r['asset_name'] ?? r['name']).toString()),
                  subtitle: Text(
                    '${r['asset_category'] ?? '—'} · ${r['status'] ?? '—'}',
                  ),
                  trailing: Text(
                    (r['value_after_depreciation'] as num?)
                            ?.toStringAsFixed(0) ??
                        '—',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceTab extends ConsumerWidget {
  const _MaintenanceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(maintenanceHistoryProvider);
    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load history: $e'),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(child: Text('No maintenance history'));
        }
        return ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (context, i) => _EntryTile(entry: entries[i]),
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  final MaintenanceEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isRepair = entry.type == 'repair';
    return ListTile(
      dense: true,
      leading: Icon(isRepair ? Icons.build : Icons.engineering),
      title: Text('${entry.title} · ${entry.asset ?? ''}'),
      subtitle: Text(
        [
          if (entry.status != null) entry.status,
          if (entry.date.isNotEmpty) entry.date,
          if (entry.cost != null) 'Cost: ${entry.cost}',
        ].join(' · '),
      ),
    );
  }
}
