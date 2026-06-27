import 'dart:convert';

import 'package:hive/hive.dart';

abstract class WarehouseLocalDataSource {
  void putList(List<String> warehouses, {String? company});
  List<String>? getList({String? company});
}

class WarehouseLocalDataSourceImpl implements WarehouseLocalDataSource {
  final Box<String> _box;

  static const String boxName = 'bude.cache.warehouses';
  static const String _listKey = 'warehouses.list';
  static const int _ttlMinutes = 30;

  WarehouseLocalDataSourceImpl(this._box);

  @override
  void putList(List<String> warehouses, {String? company}) {
    _box.put(
      _cacheKey(company),
      jsonEncode({
        'd': warehouses,
        't': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  @override
  List<String>? getList({String? company}) {
    final key = _cacheKey(company);
    final raw = _box.get(key);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(j['t'] as int);
    if (DateTime.now().difference(cachedAt).inMinutes >= _ttlMinutes) {
      _box.delete(key);
      return null;
    }
    return (j['d'] as List).cast<String>();
  }

  String _cacheKey(String? company) {
    final scope =
        (company == null || company.trim().isEmpty) ? 'all' : company.trim();
    return '$_listKey.$scope';
  }
}
