import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../../../core/sync/providers.dart';
import '../../data/datasources/item_local_data_source.dart';
import '../../data/datasources/item_remote_data_source.dart';
import '../../data/item_repository_impl.dart';
import '../../domain/entities/item.dart';
import '../../domain/repositories/item_repository.dart';
import '../../domain/usecases/get_item_by_barcode_usecase.dart';
import '../../domain/usecases/get_item_stock_usecase.dart';
import '../../domain/usecases/search_items_usecase.dart';

// Exposed so filter chip providers can call listGroups() directly.
final itemRemoteDataSourceProvider = Provider<ItemRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ItemRemoteDataSourceImpl(apiClient.dio);
});

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepositoryImpl(
    remote: ref.watch(itemRemoteDataSourceProvider),
    local: ItemLocalDataSourceImpl(ref.watch(itemCacheBoxProvider)),
  );
});

final searchItemsUseCaseProvider = Provider<SearchItemsUseCase>(
  (ref) => SearchItemsUseCase(ref.watch(itemRepositoryProvider)),
);

final getItemByBarcodeUseCaseProvider = Provider<GetItemByBarcodeUseCase>(
  (ref) => GetItemByBarcodeUseCase(ref.watch(itemRepositoryProvider)),
);

final getItemStockUseCaseProvider = Provider<GetItemStockUseCase>(
  (ref) => GetItemStockUseCase(ref.watch(itemRepositoryProvider)),
);

/// Active search filters. Equatable via record structural equality.
typedef ItemFilter = ({
  String? warehouse,
  String? itemGroup,
  bool inStock,
});

const kEmptyFilter = (warehouse: null, itemGroup: null, inStock: false);

int activeFilterCount(ItemFilter f) =>
    (f.warehouse != null ? 1 : 0) +
    (f.itemGroup != null ? 1 : 0) +
    (f.inStock ? 1 : 0);

sealed class ItemSearchState extends Equatable {
  const ItemSearchState();

  @override
  List<Object?> get props => [];
}

class ItemSearchIdle extends ItemSearchState {
  final ItemFilter filter;
  const ItemSearchIdle({this.filter = kEmptyFilter});

  @override
  List<Object?> get props => [filter];
}

class ItemSearchLoading extends ItemSearchState {
  const ItemSearchLoading();
}

class ItemSearchResults extends ItemSearchState {
  final List<Item> items;
  final String query;
  final ItemFilter filter;
  final int page;
  final bool hasMore;

  const ItemSearchResults({
    required this.items,
    required this.query,
    required this.filter,
    this.page = 0,
    this.hasMore = false,
  });

  @override
  List<Object?> get props => [items, query, filter, page, hasMore];
}

class ItemSearchError extends ItemSearchState {
  final String message;
  const ItemSearchError(this.message);

  @override
  List<Object?> get props => [message];
}

final itemSearchNotifierProvider =
    StateNotifierProvider<ItemSearchNotifier, ItemSearchState>((ref) {
  return ItemSearchNotifier(ref.watch(searchItemsUseCaseProvider));
});

class ItemSearchNotifier extends StateNotifier<ItemSearchState> {
  final SearchItemsUseCase searchUseCase;
  Timer? _debounce;
  int _requestId = 0;
  String _lastQuery = '';
  ItemFilter _filter = kEmptyFilter;

  static const _pageSize = 20;

  ItemSearchNotifier(this.searchUseCase) : super(const ItemSearchIdle());

  ItemFilter get filter => _filter;

  void onQueryChanged(String query) {
    _debounce?.cancel();
    _lastQuery = query.trim();
    if (_lastQuery.isEmpty && _filter == kEmptyFilter) {
      state = ItemSearchIdle(filter: _filter);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _run(_lastQuery, page: 0),
    );
  }

  void searchNow(String query) {
    _debounce?.cancel();
    _lastQuery = query.trim();
    _run(_lastQuery, page: 0);
  }

  void applyFilter(ItemFilter f) {
    _filter = f;
    if (_lastQuery.isEmpty && f == kEmptyFilter) {
      state = ItemSearchIdle(filter: _filter);
      return;
    }
    _run(_lastQuery, page: 0);
  }

  void clearFilters() => applyFilter(kEmptyFilter);

  Future<void> loadNextPage() async {
    final current = state;
    if (current is! ItemSearchResults || !current.hasMore) return;
    await _run(_lastQuery, page: current.page + 1, append: true);
  }

  Future<void> _run(String query, {int page = 0, bool append = false}) async {
    final id = ++_requestId;
    if (!append) state = const ItemSearchLoading();

    final result = await searchUseCase(SearchItemsParams(
      query: query,
      limit: _pageSize,
      page: page,
      warehouse: _filter.warehouse,
      itemGroup: _filter.itemGroup,
      inStock: _filter.inStock,
    ),);

    if (id != _requestId) return;
    state = result.fold(
      (failure) => ItemSearchError(failure.message),
      (newItems) {
        final prev = append && state is ItemSearchResults
            ? (state as ItemSearchResults).items
            : <Item>[];
        final merged = [...prev, ...newItems];
        return ItemSearchResults(
          items: merged,
          query: query,
          filter: _filter,
          page: page,
          hasMore: newItems.length == _pageSize,
        );
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
