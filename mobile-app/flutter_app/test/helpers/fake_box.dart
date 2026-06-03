import 'package:hive/hive.dart';

/// Minimal in-memory `Box<String>` for tests — only implements the methods
/// `SyncQueue` actually touches (get / put / delete / values). Anything else
/// throws via `noSuchMethod`.
class FakeBox implements Box<String> {
  final Map<dynamic, String> _data = {};

  @override
  String? get(dynamic key, {String? defaultValue}) => _data[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    _data.remove(key);
  }

  @override
  Iterable<String> get values => _data.values;

  @override
  noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'FakeBox does not implement ${invocation.memberName}',
    );
  }
}
