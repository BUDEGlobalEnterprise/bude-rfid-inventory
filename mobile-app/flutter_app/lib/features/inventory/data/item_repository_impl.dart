import 'package:dartz/dartz.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../domain/entities/item.dart';
import '../domain/entities/item_stock.dart';
import '../domain/entities/stock_ledger_entry.dart';
import '../domain/repositories/item_repository.dart';
import 'datasources/item_remote_data_source.dart';

class ItemRepositoryImpl implements ItemRepository {
  final ItemRemoteDataSource remote;
  ItemRepositoryImpl({required this.remote});

  @override
  Future<Either<Failure, List<Item>>> search(
    String query, {
    int limit = 20,
  }) async {
    try {
      final models = await remote.search(query, limit: limit);
      return Right(models.map((m) => m.toEntity()).toList());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, Item>> getByBarcode(String barcode) async {
    try {
      final model = await remote.getByBarcode(barcode);
      return Right(model.toEntity());
    } on NotFoundException catch (e) {
      return Left(ValidationFailure(e.message));
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
  Future<Either<Failure, List<ItemStock>>> getStock(
    String itemCode, {
    String? warehouse,
  }) async {
    try {
      final models = await remote.getStock(itemCode, warehouse: warehouse);
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
  Future<Either<Failure, List<StockLedgerEntry>>> getLedger(
    String itemCode, {
    String? warehouse,
    int limit = 50,
  }) async {
    try {
      final models = await remote.getLedger(
        itemCode,
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
