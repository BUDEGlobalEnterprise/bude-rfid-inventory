import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../warehouse/presentation/providers/warehouse_providers.dart';
import '../providers/item_group_provider.dart';
import '../providers/item_search_notifier.dart';
import '../providers/recent_searches_notifier.dart';

class FilterChipsBar extends ConsumerWidget {
  final ItemFilter filter;
  final void Function(ItemFilter) onChanged;

  const FilterChipsBar({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCount = activeFilterCount(filter);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _WarehouseChip(filter: filter, onChanged: onChanged),
          const SizedBox(width: 8),
          _ItemGroupChip(filter: filter, onChanged: onChanged),
          const SizedBox(width: 8),
          _InStockChip(filter: filter, onChanged: onChanged),
          if (activeCount > 0) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => onChanged(kEmptyFilter),
              icon: const Icon(Icons.clear, size: 16),
              label: Text('Clear ($activeCount)'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Warehouse chip ────────────────────────────────────────────────────────────

class _WarehouseChip extends ConsumerWidget {
  final ItemFilter filter;
  final void Function(ItemFilter) onChanged;
  const _WarehouseChip({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehouses = ref.watch(warehouseListProvider);
    final selected = filter.warehouse;

    return FilterChip(
      label: Text(selected != null ? 'WH: $selected' : 'Warehouse'),
      selected: selected != null,
      avatar: const Icon(Icons.warehouse_outlined, size: 16),
      onSelected: (_) => warehouses.whenData(
        (list) => _showPicker(context, list, selected, (v) {
          onChanged((warehouse: v, itemGroup: filter.itemGroup, inStock: filter.inStock));
        }),
      ),
    );
  }
}

// ── Item Group chip ───────────────────────────────────────────────────────────

class _ItemGroupChip extends ConsumerWidget {
  final ItemFilter filter;
  final void Function(ItemFilter) onChanged;
  const _ItemGroupChip({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(itemGroupsProvider);
    final selected = filter.itemGroup;

    return FilterChip(
      label: Text(selected != null ? 'Group: $selected' : 'Item Group'),
      selected: selected != null,
      avatar: const Icon(Icons.category_outlined, size: 16),
      onSelected: (_) => groups.whenData(
        (list) => _showPicker(context, list, selected, (v) {
          onChanged((warehouse: filter.warehouse, itemGroup: v, inStock: filter.inStock));
        }),
      ),
    );
  }
}

// ── In Stock toggle chip ──────────────────────────────────────────────────────

class _InStockChip extends StatelessWidget {
  final ItemFilter filter;
  final void Function(ItemFilter) onChanged;
  const _InStockChip({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: const Text('In Stock'),
      selected: filter.inStock,
      avatar: const Icon(Icons.inventory_outlined, size: 16),
      onSelected: (v) => onChanged(
        (warehouse: filter.warehouse, itemGroup: filter.itemGroup, inStock: v),
      ),
    );
  }
}

// ── Shared bottom-sheet picker ────────────────────────────────────────────────

void _showPicker(
  BuildContext context,
  List<String> options,
  String? current,
  void Function(String?) onPick,
) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => _PickerSheet(
      options: options,
      current: current,
      onPick: (v) {
        Navigator.pop(context);
        onPick(v);
      },
    ),
  );
}

class _PickerSheet extends StatelessWidget {
  final List<String> options;
  final String? current;
  final void Function(String?) onPick;

  const _PickerSheet({
    required this.options,
    required this.current,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.clear),
            title: const Text('All'),
            selected: current == null,
            onTap: () => onPick(null),
          ),
          const Divider(height: 0),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(options[i]),
                selected: options[i] == current,
                trailing: options[i] == current
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => onPick(options[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recent searches bar ───────────────────────────────────────────────────────

class RecentSearchesBar extends ConsumerWidget {
  final void Function(String) onTap;

  const RecentSearchesBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentSearchesProvider);
    if (recents.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.history, size: 16),
          const SizedBox(width: 4),
          ...recents.map(
            (q) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                label: Text(q),
                onPressed: () => onTap(q),
              ),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(recentSearchesProvider.notifier).clear(),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
