import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pending_operation.dart';

final pendingOperationsQueueProvider = Provider<PendingOperationsQueue>((ref) {
  return PendingOperationsQueue();
});

/// Single persisted queue for every offline HR operation, replacing the old
/// per-feature queues. Persistence is SharedPreferences so pending work
/// survives an app restart.
class PendingOperationsQueue {
  static const _key = 'pending_hr_operations';

  Future<List<PendingHrOperation>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map((item) => PendingHrOperation.fromJson(jsonDecode(item) as Map))
        .toList();
  }

  Future<List<PendingHrOperation>> readByType(PendingOperationType type) async {
    final all = await read();
    return all.where((op) => op.type == type).toList();
  }

  Future<void> enqueue(PendingHrOperation op) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? <String>[];
    await prefs.setStringList(_key, [...current, jsonEncode(op.toJson())]);
  }

  Future<void> discard(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? const [];
    final remaining = current.where((item) {
      final op = PendingHrOperation.fromJson(jsonDecode(item) as Map);
      return op.id != id;
    }).toList();
    await prefs.setStringList(_key, remaining);
  }

  Future<void> clearType(PendingOperationType type) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? const [];
    final remaining = current.where((item) {
      final op = PendingHrOperation.fromJson(jsonDecode(item) as Map);
      return op.type != type;
    }).toList();
    await prefs.setStringList(_key, remaining);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
