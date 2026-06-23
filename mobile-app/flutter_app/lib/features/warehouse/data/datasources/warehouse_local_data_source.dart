import 'dart:convert';

import 'package:hive/hive.dart';

abstract class WarehouseLocalDataSource {
  void putList(List<String> warehouses);
  List<String>? getList();
}

class WarehouseLocalDataSourceImpl implements WarehouseLocalDataSource {
  final Box<String> _box;

  static const String boxName = 'bude.cache.warehouses';
  static const String _listKey = 'warehouses.list';
  static const int _ttlMinutes = 30;

  WarehouseLocalDataSourceImpl(this._box);

  @override
  void putList(List<String> warehouses) {
    _box.put(
      _listKey,
      jsonEncode({
        'd': warehouses,
        't': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  @override
  List<String>? getList() {
    final raw = _box.get(_listKey);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(j['t'] as int);
    if (DateTime.now().difference(cachedAt).inMinutes >= _ttlMinutes) {
      _box.delete(_listKey);
      return null;
    }
    return (j['d'] as List).cast<String>();
  }
}
