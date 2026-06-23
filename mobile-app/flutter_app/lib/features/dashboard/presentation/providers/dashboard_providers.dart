import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/providers.dart';
import '../../../analytics/domain/entities/throughput_data.dart';
import '../../../analytics/presentation/providers/analytics_providers.dart';

/// Live connectivity flag for the System Status card. Mirrors the private
/// stream used by OfflineBanner.
final isOnlineProvider = StreamProvider<bool>((ref) {
  return ref.watch(networkInfoProvider).onConnectivityChanged();
});

// ponytail: thin wrapper so dashboard_screen doesn't need to fold buckets inline
final todayOpCountProvider = Provider.autoDispose<int>((ref) {
  final now = DateTime.now();
  return ref
          .watch(throughputProvider)
          .valueOrNull
          ?.buckets
          .firstWhere(
            (b) =>
                b.date.year == now.year &&
                b.date.month == now.month &&
                b.date.day == now.day,
            orElse: () => DayBucket(date: now),
          )
          .totalCount ??
      0;
});
