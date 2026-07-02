import 'package:bude_hr/core/offline/read_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('save then load round-trips data and a timestamp', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = ReadCache();

    await cache.save('leave', [
      {'leave_type': 'Annual'},
    ]);
    final loaded = await cache.load('leave');

    expect(loaded, isNotNull);
    expect((loaded!.data as List).first['leave_type'], 'Annual');
    expect(loaded.fetchedAt, isA<DateTime>());
  });

  test('cacheThrough returns fresh data and caches it on success', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = ReadCache();

    final result = await cacheThrough<int>(
      cache: cache,
      key: 'count',
      fetchRaw: () async => 3,
      parse: (raw) => raw as int,
    );

    expect(result.data, 3);
    expect(result.fromCache, isFalse);
    expect((await cache.load('count'))!.data, 3);
  });

  test('cacheThrough falls back to cache when the fetch fails', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = ReadCache();
    await cache.save('count', 7);

    final result = await cacheThrough<int>(
      cache: cache,
      key: 'count',
      fetchRaw: () async => throw Exception('offline'),
      parse: (raw) => raw as int,
    );

    expect(result.data, 7);
    expect(result.fromCache, isTrue);
  });

  test('cacheThrough rethrows when the fetch fails and no cache exists',
      () async {
    SharedPreferences.setMockInitialValues({});
    final cache = ReadCache();

    expect(
      () => cacheThrough<int>(
        cache: cache,
        key: 'missing',
        fetchRaw: () async => throw Exception('offline'),
        parse: (raw) => raw as int,
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('routes storage through the injected backend (e.g. encrypted)',
      () async {
    final store = _MemoryStore();
    final cache = ReadCache(store: store, keyPrefix: 'secure_cache_');

    await cache.save('salary_slips', [
      {'net_pay': 1000},
    ]);

    // Sensitive data lands only in the injected (here in-memory) store.
    expect(store.data.keys.single, 'secure_cache_salary_slips');
    final loaded = await cache.load('salary_slips');
    expect((loaded!.data as List).first['net_pay'], 1000);
  });
}

class _MemoryStore implements CacheStore {
  final Map<String, String> data = {};

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> delete(String key) async => data.remove(key);
}
