import 'package:dartz/dartz.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../domain/entities/warehouse_stock_line.dart';
import '../domain/repositories/warehouse_repository.dart';
import 'datasources/warehouse_remote_data_source.dart';

class WarehouseRepositoryImpl implements WarehouseRepository {
  final WarehouseRemoteDataSource remote;
  WarehouseRepositoryImpl({required this.remote});

  @override
  Future<Either<Failure, List<String>>> listWarehouses({
    int limit = 100,
  }) async {
    try {
      final names = await remote.listWarehouses(limit: limit);
      return Right(names);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, List<WarehouseStockLine>>> getStock(
    String warehouse, {
    int limit = 100,
  }) async {
    try {
      final models = await remote.getStock(warehouse, limit: limit);
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
