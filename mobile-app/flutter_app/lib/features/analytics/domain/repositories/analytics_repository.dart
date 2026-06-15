import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/reconciliation_summary.dart';
import '../entities/stock_aging_row.dart';

abstract class AnalyticsRepository {
  Future<Either<Failure, List<StockAgingRow>>> getStockAging(
    String warehouse, {
    int thresholdDays = 30,
    int limit = 100,
  });

  Future<Either<Failure, List<ReconciliationSummary>>> getReconciliationHistory({
    String? warehouse,
    int limit = 20,
  });
}
