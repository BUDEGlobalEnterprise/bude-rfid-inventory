import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/hardware/entities/scan_event.dart';
import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/loading_shimmer.dart';
import '../../../core/ui/operational_components.dart';
import '../../../core/utils/locale_ext.dart';
import '../../settings/presentation/providers/settings_notifier.dart';
import '../domain/entities/item.dart';
import 'providers/item_search_notifier.dart';
import 'providers/recent_searches_notifier.dart';
import 'widgets/filter_chips_bar.dart';

class ItemSearchScreen extends ConsumerStatefulWidget {
  /// Optional initial query passed via GoRouter extra: {'query': '...'}.
  final String? initialQuery;

  const ItemSearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<ItemSearchScreen> createState() => _ItemSearchScreenState();
}

class _ItemSearchScreenState extends ConsumerState<ItemSearchScreen> {
  final _queryCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _fieldFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _fieldFocused = _focusNode.hasFocus);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsNotifierProvider);
      final ItemFilter savedFilter = (
        warehouse: settings.lastSearchWarehouse,
        itemGroup: settings.lastSearchItemGroup,
        inStock: settings.lastSearchInStock,
      );
      if (savedFilter != kEmptyFilter) {
        ref.read(itemSearchNotifierProvider.notifier).applyFilter(savedFilter);
      }

      final q = widget.initialQuery ?? '';
      if (q.isNotEmpty) {
        _queryCtrl.text = q;
        ref.read(itemSearchNotifierProvider.notifier).searchNow(q);
      }
    });
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _openScanner() async {
    final result = await context.push<ScanEvent>('/scan');
    if (result == null || !mounted) return;
    final repository = ref.read(itemRepositoryProvider);
    final lookup = await repository.getByBarcode(result.barcode);
    if (!mounted) return;
    lookup.fold(
      (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
      (item) => context.push('/items/${Uri.encodeComponent(item.itemCode)}'),
    );
  }

  void _onQuerySubmitted(String q) {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return;
    ref.read(recentSearchesProvider.notifier).add(trimmed);
    ref.read(itemSearchNotifierProvider.notifier).searchNow(trimmed);
    _focusNode.unfocus();
  }

  void _applyFilter(ItemFilter f) {
    ref.read(itemSearchNotifierProvider.notifier).applyFilter(f);
    ref.read(settingsNotifierProvider.notifier).setLastSearchFilter(
          warehouse: f.warehouse,
          itemGroup: f.itemGroup,
          inStock: f.inStock,
        );
  }

  void _openFilters(ItemFilter filter) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.filterItems,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              FilterChipsBar(filter: filter, onChanged: _applyFilter),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    _applyFilter(kEmptyFilter);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.clear),
                  label: Text(context.l10n.clearFilters),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemSearchNotifierProvider);
    final filter = switch (state) {
      ItemSearchIdle(:final filter) => filter,
      ItemSearchResults(:final filter) => filter,
      _ => ref.read(itemSearchNotifierProvider.notifier).filter,
    };
    final activeCount = activeFilterCount(filter);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _queryCtrl,
          focusNode: _focusNode,
          autofocus: widget.initialQuery == null,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: context.l10n.searchItems,
            prefixIcon: const Icon(Icons.search),
            border: InputBorder.none,
            suffixIcon: _queryCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _queryCtrl.clear();
                      ref
                          .read(itemSearchNotifierProvider.notifier)
                          .onQueryChanged('');
                    },
                  )
                : null,
          ),
          onChanged: (v) {
            setState(() {});
            ref.read(itemSearchNotifierProvider.notifier).onQueryChanged(v);
          },
          onSubmitted: _onQuerySubmitted,
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.filterItems,
            onPressed: () => _openFilters(filter),
            icon: activeCount > 0
                ? Badge(
                    label: Text('$activeCount'),
                    child: const Icon(Icons.filter_list),
                  )
                : const Icon(Icons.filter_list),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScanner,
        tooltip: context.l10n.scanBarcode,
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(context.l10n.scan),
      ),
      body: Column(
        children: [
          FilterChipsBar(filter: filter, onChanged: _applyFilter),
          if (_fieldFocused && _queryCtrl.text.trim().isEmpty)
            RecentSearchesBar(
              onTap: (q) {
                _queryCtrl.text = q;
                _onQuerySubmitted(q);
              },
            ),
          Expanded(child: _ResultsView(state: state)),
        ],
      ),
    );
  }
}

class _ResultsView extends ConsumerWidget {
  final ItemSearchState state;
  const _ResultsView({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (state) {
      ItemSearchIdle(:final filter) => _EmptyIdle(filter: filter),
      ItemSearchLoading() => const ShimmerList(count: 8),
      ItemSearchError(:final message) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ItemSearchResults(
        :final items,
        :final query,
        :final filter,
        :final hasMore,
      ) =>
        items.isEmpty
            ? _EmptyResults(query: query, filter: filter)
            : _ItemList(items: items, hasMore: hasMore),
    };
  }
}

class _EmptyIdle extends StatelessWidget {
  final ItemFilter filter;
  const _EmptyIdle({required this.filter});

  @override
  Widget build(BuildContext context) {
    final hasFilters = activeFilterCount(filter) > 0;
    return EmptyStateView(
      icon: hasFilters ? Icons.filter_alt_outlined : Icons.manage_search,
      title: hasFilters
          ? context.l10n.searchWithinFilters
          : context.l10n.findItemFast,
      subtitle: hasFilters
          ? context.l10n.searchFilteredCatalogHint
          : context.l10n.searchItemsDetailedHint,
    );
  }
}

class _EmptyResults extends StatelessWidget {
  final String query;
  final ItemFilter filter;
  const _EmptyResults({required this.query, required this.filter});

  @override
  Widget build(BuildContext context) {
    final hasFilters = activeFilterCount(filter) > 0;
    final base = query.isNotEmpty
        ? context.l10n.noItemsMatch(query)
        : context.l10n.noItemsFound;
    final hint = filter.inStock
        ? 'No items in stock match your search.'
        : context.l10n.adjustSearchOrFilters;

    return EmptyStateView(
      icon: Icons.inventory_2_outlined,
      title: hasFilters && query.isEmpty
          ? context.l10n.noItemsWithActiveFilters
          : base,
      subtitle: hint,
    );
  }
}

class _ItemList extends ConsumerWidget {
  final List<Item> items;
  final bool hasMore;
  const _ItemList({required this.items, required this.hasMore});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (context, i) {
        if (i == items.length) {
          return _LoadMoreButton(
            onTap: () =>
                ref.read(itemSearchNotifierProvider.notifier).loadNextPage(),
          );
        }
        return _ItemTile(item: items[i]);
      },
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LoadMoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(context.l10n.loadMore),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Item item;
  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chips = [
      if (item.itemGroup != null && item.itemGroup!.isNotEmpty)
        BudeStatusChip(
          label: item.itemGroup!,
          icon: Icons.category_outlined,
          color: scheme.primary,
        ),
      if (item.stockUom != null && item.stockUom!.isNotEmpty)
        BudeStatusChip(
          label: item.stockUom!,
          icon: Icons.straighten,
          color: scheme.tertiary,
        ),
      if (item.disabled)
        BudeStatusChip(
          label: context.l10n.disabledStatus,
          icon: Icons.block,
          color: scheme.error,
        ),
    ];

    return InkWell(
      onTap: () => context.push('/items/${Uri.encodeComponent(item.itemCode)}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.inventory_2_outlined, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.itemCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: chips),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: context.l10n.itemActions,
              icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
              onSelected: (value) {
                final route = switch (value) {
                  'transfer' => '/transfer',
                  'receipt' => '/receipt',
                  'count' => '/reconcile',
                  _ => null,
                };
                if (route != null) context.push(route, extra: item);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'transfer',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.swap_horiz),
                    title: Text(context.l10n.transfer),
                  ),
                ),
                PopupMenuItem(
                  value: 'receipt',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.input),
                    title: Text(context.l10n.receive),
                  ),
                ),
                PopupMenuItem(
                  value: 'count',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.fact_check),
                    title: Text(context.l10n.count),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
