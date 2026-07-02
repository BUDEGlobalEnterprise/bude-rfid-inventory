import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A read-only result plus when it was fetched and whether it came from the
/// on-device cache (i.e. the network call failed and we fell back to it).
class Cached<T> {
  const Cached(this.data, this.fetchedAt, {this.fromCache = false});

  final T data;
  final DateTime fetchedAt;
  final bool fromCache;
}

/// Pluggable key/value backend so caches can choose plaintext or encrypted
/// storage per sensitivity.
abstract class CacheStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

class _PrefsCacheStore implements CacheStore {
  @override
  Future<void> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);

  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> delete(String key) async =>
      (await SharedPreferences.getInstance()).remove(key);
}

class _SecureCacheStore implements CacheStore {
  const _SecureCacheStore(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Persists the raw JSON of read-only responses so screens can show stale
/// data (labelled with its age) when the network is unavailable. Use
/// [ReadCache.secure] for sensitive payloads (e.g. salary).
class ReadCache {
  ReadCache({CacheStore? store, this.keyPrefix = 'read_cache_'})
      : _store = store ?? _PrefsCacheStore();

  /// Encrypted-at-rest cache for sensitive read-only data.
  factory ReadCache.secure({String keyPrefix = 'secure_cache_'}) {
    return ReadCache(
      store: const _SecureCacheStore(FlutterSecureStorage()),
      keyPrefix: keyPrefix,
    );
  }

  final CacheStore _store;
  final String keyPrefix;

  Future<void> save(String key, Object jsonData) async {
    await _store.write(
      '$keyPrefix$key',
      jsonEncode({
        'fetched_at': DateTime.now().toIso8601String(),
        'data': jsonData,
      }),
    );
  }

  Future<({Object? data, DateTime fetchedAt})?> load(String key) async {
    final raw = await _store.read('$keyPrefix$key');
    if (raw == null) return null;
    final decoded = jsonDecode(raw) as Map;
    return (
      data: decoded['data'],
      fetchedAt: DateTime.parse(decoded['fetched_at'] as String),
    );
  }
}

/// Runs [fetchRaw]; on success caches the raw payload and returns it fresh, on
/// failure falls back to the cached payload (or rethrows if none exists).
Future<Cached<T>> cacheThrough<T>({
  required ReadCache cache,
  required String key,
  required Future<Object> Function() fetchRaw,
  required T Function(Object raw) parse,
}) async {
  try {
    final raw = await fetchRaw();
    await cache.save(key, raw);
    return Cached(parse(raw), DateTime.now());
  } catch (_) {
    final cached = await cache.load(key);
    if (cached == null) rethrow;
    return Cached(parse(cached.data as Object), cached.fetchedAt, fromCache: true);
  }
}
