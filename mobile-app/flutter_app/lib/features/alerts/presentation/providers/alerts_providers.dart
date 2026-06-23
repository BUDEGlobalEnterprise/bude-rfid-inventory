import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../data/alerts_remote_data_source.dart';

final alertsDataSourceProvider = Provider<AlertsRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AlertsRemoteDataSource(apiClient.dio);
});

const _alertsCacheKey = 'cache.alert_count';

// ponytail: cache alert count for offline dashboard — just an int in SharedPreferences
final alertsProvider = FutureProvider.autoDispose<AlertsResult>((ref) async {
  try {
    final result = await ref.watch(alertsDataSourceProvider).list();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_alertsCacheKey, result.total);
    return result;
  } on NetworkException {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getInt(_alertsCacheKey);
    if (cached != null) {
      return AlertsResult(alerts: const [], total: cached);
    }
    rethrow;
  }
});

/// Open-alert count for the dashboard bell badge. 0 while loading/erroring so
/// the badge never blocks on the network.
final alertCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(alertsProvider).valueOrNull?.total ?? 0;
});
