import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/item_model.dart';

abstract class ItemLocalDataSource {
  void putSearchResult(String cacheKey, List<ItemModel> items);
  List<ItemModel>? getSearchResult(String cacheKey);
  void putItem(String itemCode, ItemModel item);
  ItemModel? getItem(String itemCode);
}

class ItemLocalDataSourceImpl implements ItemLocalDataSource {
  final Box<String> _box;

  static const String boxName = 'bude.cache.items';
  static const int _searchTtlHours = 1;
  static const int _itemTtlHours = 24;

  ItemLocalDataSourceImpl(this._box);

  static String searchKey(
    String query,
    String? warehouse,
    String? itemGroup,
    bool inStock,
    int page,
  ) =>
      'search:$query:${warehouse ?? ''}:${itemGroup ?? ''}:$inStock:$page';

  @override
  void putSearchResult(String cacheKey, List<ItemModel> items) {
    _box.put(
      cacheKey,
      _encode(items.map((i) => i.toJson()).toList()),
    );
  }

  @override
  List<ItemModel>? getSearchResult(String cacheKey) {
    return _decode<List<ItemModel>>(cacheKey, _searchTtlHours, (data) {
      return (data as List)
          .cast<Map<String, dynamic>>()
          .map(ItemModel.fromJson)
          .toList();
    });
  }

  @override
  void putItem(String itemCode, ItemModel item) {
    _box.put('item:$itemCode', _encode(item.toJson()));
  }

  @override
  ItemModel? getItem(String itemCode) {
    return _decode<ItemModel>('item:$itemCode', _itemTtlHours, (data) {
      return ItemModel.fromJson((data as Map).cast<String, dynamic>());
    });
  }

  String _encode(dynamic data) => jsonEncode({
        'd': data,
        't': DateTime.now().millisecondsSinceEpoch,
      });

  T? _decode<T>(String key, int ttlHours, T Function(dynamic) fromData) {
    final raw = _box.get(key);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final cachedAt =
        DateTime.fromMillisecondsSinceEpoch(j['t'] as int);
    if (DateTime.now().difference(cachedAt).inHours >= ttlHours) {
      _box.delete(key);
      return null;
    }
    return fromData(j['d']);
  }
}
