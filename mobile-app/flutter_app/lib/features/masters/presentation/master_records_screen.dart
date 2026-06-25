import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/loading_shimmer.dart';
import '../domain/master_def.dart';
import 'providers/masters_providers.dart';

/// Searchable record list for one master, with create (FAB), edit and
/// enable/disable. Online-only.
class MasterRecordsScreen extends ConsumerStatefulWidget {
  final String masterKey;
  const MasterRecordsScreen({super.key, required this.masterKey});

  @override
  ConsumerState<MasterRecordsScreen> createState() =>
      _MasterRecordsScreenState();
}

class _MasterRecordsScreenState extends ConsumerState<MasterRecordsScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  MasterDef? _defFrom(List<MasterDef>? list) {
    if (list == null) return null;
    for (final m in list) {
      if (m.key == widget.masterKey) return m;
    }
    return null;
  }

  String _rowTitle(Map<String, dynamic> row) {
    for (final e in row.entries) {
      if (e.key != 'name' && e.value is String && (e.value as String).isNotEmpty) {
        return e.value as String;
      }
    }
    return row['name']?.toString() ?? '(unnamed)';
  }

  bool _rowDisabled(Map<String, dynamic> row) {
    if (row['disabled'] == 1 || row['disabled'] == true) return true;
    if (row.containsKey('enabled') &&
        (row['enabled'] == 0 || row['enabled'] == false)) {
      return true;
    }
    final status = row['status'];
    if (status is String && status.isNotEmpty && status != 'Active') return true;
    return false;
  }

  Future<void> _openForm(String path) async {
    await context.push(path);
    ref.invalidate(masterRecordsProvider); // refresh after create/edit
  }

  Future<void> _toggleDisabled(String name, bool disabled) async {
    try {
      await ref
          .read(mastersDataSourceProvider)
          .setDisabled(widget.masterKey, name, disabled);
      ref.invalidate(masterRecordsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(disabled ? 'Disabled $name' : 'Enabled $name')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final def = _defFrom(ref.watch(mastersCatalogProvider).valueOrNull);
    final recordsAsync = ref.watch(
      masterRecordsProvider(
        (key: widget.masterKey, search: _search.isEmpty ? null : _search),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(def?.label ?? widget.masterKey)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm('/masters/${widget.masterKey}/new'),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      ),
              ),
              onSubmitted: (v) => setState(() => _search = v.trim()),
            ),
          ),
          Expanded(
            child: recordsAsync.when(
              loading: () => const ShimmerList(count: 10),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Failed to load: $e', textAlign: TextAlign.center),
                ),
              ),
              data: (rows) => rows.isEmpty
                  ? const EmptyStateView(
                      icon: Icons.inbox_outlined,
                      title: 'No records',
                      subtitle: 'Tap New to add one.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(masterRecordsProvider),
                      child: ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (context, i) {
                          final row = rows[i];
                          final name = row['name']?.toString() ?? '';
                          final disabled = _rowDisabled(row);
                          return ListTile(
                            title: Text(_rowTitle(row)),
                            subtitle: Text(name),
                            trailing: PopupMenuButton<String>(
                              onSelected: (action) {
                                if (action == 'edit') {
                                  _openForm(
                                    '/masters/${widget.masterKey}/edit/'
                                    '${Uri.encodeComponent(name)}',
                                  );
                                } else if (action == 'toggle') {
                                  _toggleDisabled(name, !disabled);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                if (def?.canDisable ?? false)
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(disabled ? 'Enable' : 'Disable'),
                                  ),
                              ],
                            ),
                            onTap: () => _openForm(
                              '/masters/${widget.masterKey}/edit/'
                              '${Uri.encodeComponent(name)}',
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
