import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../data/datasources/item_remote_data_source.dart';
import '../../data/item_repository_impl.dart';
import '../../domain/entities/item.dart';
import '../../domain/repositories/item_repository.dart';
import '../../domain/usecases/get_item_by_barcode_usecase.dart';
import '../../domain/usecases/get_item_stock_usecase.dart';
import '../../domain/usecases/search_items_usecase.dart';

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ItemRepositoryImpl(
    remote: ItemRemoteDataSourceImpl(apiClient.dio),
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

sealed class ItemSearchState extends Equatable {
  const ItemSearchState();

  @override
  List<Object?> get props => [];
}

class ItemSearchIdle extends ItemSearchState {
  const ItemSearchIdle();
}

class ItemSearchLoading extends ItemSearchState {
  const ItemSearchLoading();
}

class ItemSearchResults extends ItemSearchState {
  final List<Item> items;
  final String query;
  const ItemSearchResults({required this.items, required this.query});

  @override
  List<Object?> get props => [items, query];
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

  ItemSearchNotifier(this.searchUseCase) : super(const ItemSearchIdle());

  void onQueryChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = const ItemSearchIdle();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(trimmed));
  }

  Future<void> _run(String query) async {
    final id = ++_requestId;
    state = const ItemSearchLoading();
    final result = await searchUseCase(SearchItemsParams(query: query));
    if (id != _requestId) return;
    state = result.fold(
      (failure) => ItemSearchError(failure.message),
      (items) => ItemSearchResults(items: items, query: query),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
