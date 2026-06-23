import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/loading_shimmer.dart';
import 'providers/asset_providers.dart';

const _statuses = [
  'Submitted',
  'Partially Depreciated',
  'Fully Depreciated',
  'In Maintenance',
  'Out of Order',
  'Sold',
  'Scrapped',
];

class AssetListScreen extends ConsumerStatefulWidget {
  const AssetListScreen({super.key});

  @override
  ConsumerState<AssetListScreen> createState() => _AssetListScreenState();
}

class _AssetListScreenState extends ConsumerState<AssetListScreen> {
  final _searchCtrl = TextEditingController();
  String? _status;
  String? _category;
  String? _location;
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = (
      search: _search.isEmpty ? null : _search,
      location: _location,
      status: _status,
      category: _category,
    );
    final assetsAsync = ref.watch(assetListProvider(filter));

    return Scaffold(
      appBar: AppBar(title: const Text('Assets')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search assets',
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
          _FilterChips(
            status: _status,
            category: _category,
            location: _location,
            onStatus: (v) => setState(() => _status = v),
            onCategory: (v) => setState(() => _category = v),
            onLocation: (v) => setState(() => _location = v),
          ),
          Expanded(
            child: assetsAsync.when(
              loading: () => const ShimmerList(count: 10),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load assets: $e',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (assets) => assets.isEmpty
                  ? const EmptyStateView(
                      icon: Icons.precision_manufacturing_outlined,
                      title: 'No assets found',
                      subtitle: 'Try adjusting the filters or search.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(assetListProvider(filter)),
                      child: ListView.separated(
                        itemCount: assets.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (context, i) {
                          final a = assets[i];
                          return ListTile(
                            leading: const Icon(Icons.precision_manufacturing),
                            title: Text(a.assetName),
                            subtitle: Text(
                              [a.name, if (a.location != null) a.location]
                                  .join(' · '),
                            ),
                            trailing: _StatusChip(status: a.status),
                            onTap: () => context.push(
                              '/assets/${Uri.encodeComponent(a.name)}',
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

class _FilterChips extends ConsumerWidget {
  final String? status;
  final String? category;
  final String? location;
  final ValueChanged<String?> onStatus;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String?> onLocation;

  const _FilterChips({
    required this.status,
    required this.category,
    required this.location,
    required this.onStatus,
    required this.onCategory,
    required this.onLocation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(assetCategoriesProvider).valueOrNull ?? [];
    final locations = ref.watch(assetLocationsProvider).valueOrNull ?? [];

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _DropChip(
            label: 'Status',
            value: status,
            options: _statuses,
            onSelected: onStatus,
          ),
          const SizedBox(width: 8),
          _DropChip(
            label: 'Category',
            value: category,
            options: categories,
            onSelected: onCategory,
          ),
          const SizedBox(width: 8),
          _DropChip(
            label: 'Location',
            value: location,
            options: locations.map((l) => l.name).toList(),
            onSelected: onLocation,
          ),
        ],
      ),
    );
  }
}

class _DropChip extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onSelected;

  const _DropChip({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) => onSelected(v == '__all__' ? null : v),
      itemBuilder: (context) => [
        const PopupMenuItem(value: '__all__', child: Text('All')),
        for (final o in options) PopupMenuItem(value: o, child: Text(o)),
      ],
      child: Chip(
        label: Text(value ?? label),
        avatar: Icon(
          value == null ? Icons.filter_list : Icons.check,
          size: 16,
        ),
        backgroundColor: value == null
            ? null
            : Theme.of(context).colorScheme.secondaryContainer,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String? status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final danger = status == 'Out of Order' || status == 'Scrapped';
    final warn = status == 'In Maintenance';
    final color = danger
        ? scheme.error
        : warn
            ? scheme.tertiary
            : scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status!,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
