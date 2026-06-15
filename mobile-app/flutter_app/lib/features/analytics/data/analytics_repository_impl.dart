import 'package:dartz/dartz.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../domain/entities/reconciliation_summary.dart';
import '../domain/entities/stock_aging_row.dart';
import '../domain/repositories/analytics_repository.dart';
import 'datasources/analytics_remote_data_source.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final AnalyticsRemoteDataSource remote;
  AnalyticsRepositoryImpl({required this.remote});

  @override
  Future<Either<Failure, List<StockAgingRow>>> getStockAging(
    String warehouse, {
    int thresholdDays = 30,
    int limit = 100,
  }) async {
    try {
      final models = await remote.getStockAging(
        warehouse,
        thresholdDays: thresholdDays,
        limit: limit,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, List<ReconciliationSummary>>> getReconciliationHistory({
    String? warehouse,
    int limit = 20,
  }) async {
    try {
      final models = await remote.getReconciliationHistory(
        warehouse: warehouse,
        limit: limit,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }
}
