import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/providers.dart';
import '../../../../core/sync/pending_operation.dart';
import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../data/analytics_repository_impl.dart';
import '../../data/datasources/analytics_remote_data_source.dart';
import '../../domain/entities/reconciliation_summary.dart';
import '../../domain/entities/stock_aging_row.dart';
import '../../domain/entities/throughput_data.dart';
import '../../domain/repositories/analytics_repository.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AnalyticsRepositoryImpl(
    remote: AnalyticsRemoteDataSourceImpl(apiClient.dio),
  );
});

// ── Stock aging ───────────────────────────────────────────────────────────────

typedef AgingKey = ({String warehouse, int thresholdDays});

final stockAgingProvider = FutureProvider.family
    .autoDispose<List<StockAgingRow>, AgingKey>((ref, key) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final result = await repo.getStockAging(
    key.warehouse,
    thresholdDays: key.thresholdDays,
  );
  return result.fold((f) => throw f, (d) => d);
});

// ── Reconciliation history ────────────────────────────────────────────────────

final reconciliationHistoryProvider = FutureProvider.family
    .autoDispose<List<ReconciliationSummary>, String?>((ref, warehouse) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final result = await repo.getReconciliationHistory(warehouse: warehouse);
  return result.fold((f) => throw f, (d) => d);
});

// ── Throughput (local Hive data only) ────────────────────────────────────────

final throughputProvider =
    FutureProvider.autoDispose<ThroughputData>((ref) async {
  final opsAsync = ref.watch(allOpsProvider);
  final ops = await opsAsync.when(
    data: (list) async => list,
    loading: () async {
      // Wait for the stream to emit at least one value.
      await Future<void>.delayed(Duration.zero);
      return <PendingOperation>[];
    },
    error: (_, __) async => <PendingOperation>[],
  );

  if (ops.isEmpty) {
    return const ThroughputData(
      buckets: [],
      totalOps: 0,
      successRate: 0,
      mostActiveDay: null,
    );
  }

  final Map<String, Map<String, int>> byDateType = {};
  int succeededCount = 0;
  int totalCount = 0;

  for (final op in ops) {
    totalCount++;
    if (op.status == OpStatus.succeeded) succeededCount++;

    final dateKey = _dateKey(op.createdAt);
    byDateType.putIfAbsent(dateKey, () => {});
    byDateType[dateKey]![op.type] =
        (byDateType[dateKey]![op.type] ?? 0) + 1;

    if (op.status == OpStatus.failed) {
      byDateType[dateKey]!['_failed'] =
          (byDateType[dateKey]!['_failed'] ?? 0) + 1;
    }
  }

  final buckets = byDateType.entries.map((e) {
    final date = DateTime.parse(e.key);
    final counts = e.value;
    return DayBucket(
      date: date,
      transferCount: counts['transfer'] ?? 0,
      receiptCount: counts['receipt'] ?? 0,
      reconcileCount: counts['reconcile'] ?? 0,
      failedCount: counts['_failed'] ?? 0,
    );
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  DateTime? mostActive;
  int maxOps = 0;
  for (final b in buckets) {
    if (b.totalCount > maxOps) {
      maxOps = b.totalCount;
      mostActive = b.date;
    }
  }

  return ThroughputData(
    buckets: buckets,
    totalOps: totalCount,
    successRate: totalCount > 0 ? succeededCount / totalCount : 0.0,
    mostActiveDay: mostActive,
  );
});

String _dateKey(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-'
    '${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')}';
