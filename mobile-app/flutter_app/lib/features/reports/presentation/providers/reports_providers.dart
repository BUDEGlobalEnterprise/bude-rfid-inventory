import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../data/reports_remote_data_source.dart';

final reportsDataSourceProvider = Provider<ReportsRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ReportsRemoteDataSource(apiClient.dio);
});

// ponytail: SharedPreferences cache — no new abstraction for dashboard-only read
const _assetKpisCacheKey = 'cache.asset_kpis';

final assetKpisProvider = FutureProvider.autoDispose<AssetKpis>((ref) async {
  try {
    final result = await ref.watch(reportsDataSourceProvider).summary();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_assetKpisCacheKey, jsonEncode(result.toJson()));
    return result;
  } on NetworkException {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_assetKpisCacheKey);
    if (cached != null) {
      return AssetKpis.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,);
    }
    rethrow;
  }
});

final assetRegisterProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(reportsDataSourceProvider).register();
});

final maintenanceHistoryProvider =
    FutureProvider.autoDispose<List<MaintenanceEntry>>((ref) {
  return ref.watch(reportsDataSourceProvider).maintenanceHistory();
});
