import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/hardware/entities/scan_event.dart';
import '../../../core/utils/locale_ext.dart';
import '../domain/entities/item.dart';
import 'providers/item_search_notifier.dart';
import 'providers/recent_searches_notifier.dart';
import '../../settings/presentation/providers/settings_notifier.dart';
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
      // Restore persisted filter from settings.
      final settings = ref.read(settingsNotifierProvider);
      final ItemFilter savedFilter = (
        warehouse: settings.lastSearchWarehouse,
        itemGroup: settings.lastSearchItemGroup,
        inStock: settings.lastSearchInStock,
      );
      if (savedFilter != kEmptyFilter) {
        ref.read(itemSearchNotifierProvider.notifier).applyFilter(savedFilter);
      }

      // Pre-fill initial query (from dashboard search bar).
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
    // Persist last-used filter.
    ref.read(settingsNotifierProvider.notifier).setLastSearchFilter(
          warehouse: f.warehouse,
          itemGroup: f.itemGroup,
          inStock: f.inStock,
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
            setState(() {}); // rebuild suffix icon
            ref.read(itemSearchNotifierProvider.notifier).onQueryChanged(v);
          },
          onSubmitted: _onQuerySubmitted,
        ),
        actions: [
          if (activeCount > 0)
            Badge(
              label: Text('$activeCount'),
              child: const Icon(Icons.filter_list),
            )
          else
            const Icon(Icons.filter_list),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openScanner,
        tooltip: 'Scan barcode',
        child: const Icon(Icons.qr_code_scanner),
      ),
      body: Column(
        children: [
          FilterChipsBar(filter: filter, onChanged: _applyFilter),
          // Recent searches: shown when field focused + query empty.
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

// ── Results view ──────────────────────────────────────────────────────────────

class _ResultsView extends ConsumerWidget {
  final ItemSearchState state;
  const _ResultsView({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (state) {
      ItemSearchIdle(:final filter) => _EmptyIdle(filter: filter),
      ItemSearchLoading() => const Center(child: CircularProgressIndicator()),
      ItemSearchError(:final message) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ItemSearchResults(:final items, :final query, :final filter, :final hasMore) =>
        items.isEmpty
            ? _EmptyResults(query: query, filter: filter)
            : _ItemList(items: items, hasMore: hasMore),
    };
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────

class _EmptyIdle extends StatelessWidget {
  final ItemFilter filter;
  const _EmptyIdle({required this.filter});

  @override
  Widget build(BuildContext context) {
    final hasFilters = activeFilterCount(filter) > 0;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 48, color: Theme.of(context).disabledColor),
          const SizedBox(height: 12),
          Text(
            hasFilters
                ? 'Type to search within active filters'
                : 'Type to search items by code, name or barcode',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
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
    final base = query.isNotEmpty ? 'No items match "$query"' : 'No items found';
    final suffix = hasFilters ? ' with active filters — try clearing filters' : '';

    String hint = '';
    if (filter.inStock) hint = 'No items in stock match your search.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 48, color: Theme.of(context).disabledColor,),
            const SizedBox(height: 12),
            Text(
              '$base$suffix',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (hint.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Item list + load more ─────────────────────────────────────────────────────

class _ItemList extends ConsumerWidget {
  final List<Item> items;
  final bool hasMore;
  const _ItemList({required this.items, required this.hasMore});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
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
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Load more'),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Item item;
  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item.itemName),
      subtitle: Text(
        [item.itemCode, if (item.itemGroup != null) item.itemGroup!].join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () =>
          context.push('/items/${Uri.encodeComponent(item.itemCode)}'),
    );
  }
}
