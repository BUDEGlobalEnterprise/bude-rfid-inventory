import 'package:dartz/dartz.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../domain/entities/item.dart';
import '../domain/entities/item_stock.dart';
import '../domain/entities/stock_ledger_entry.dart';
import '../domain/repositories/item_repository.dart';
import 'datasources/item_local_data_source.dart';
import 'datasources/item_remote_data_source.dart';

class ItemRepositoryImpl implements ItemRepository {
  final ItemRemoteDataSource remote;
  final ItemLocalDataSource local;

  ItemRepositoryImpl({required this.remote, required this.local});

  @override
  Future<Either<Failure, List<Item>>> search(
    String query, {
    int limit = 20,
    int page = 0,
    String? warehouse,
    String? itemGroup,
    bool inStock = false,
  }) async {
    try {
      final models = await remote.search(
        query,
        limit: limit,
        page: page,
        warehouse: warehouse,
        itemGroup: itemGroup,
        inStock: inStock,
      );
      // Cache first-page results for offline use (pagination beyond p0 not cached).
      if (page == 0) {
        local.putSearchResult(
          ItemLocalDataSourceImpl.searchKey(
              query, warehouse, itemGroup, inStock, 0,),
          models,
        );
      }
      return Right(models.map((m) => m.toEntity()).toList());
    } on NetworkException {
      final cacheKey = ItemLocalDataSourceImpl.searchKey(
          query, warehouse, itemGroup, inStock, page,);
      final cached = local.getSearchResult(cacheKey);
      if (cached != null) {
        return Right(cached.map((m) => m.toEntity()).toList());
      }
      return const Left(NetworkFailure('No internet connection.'));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, Item>> getByBarcode(String barcode) async {
    // Cache-first: barcodes resolve to stable item codes.
    final cached = local.getItem(barcode);
    if (cached != null) return Right(cached.toEntity());

    try {
      final model = await remote.getByBarcode(barcode);
      local.putItem(model.itemCode, model);
      return Right(model.toEntity());
    } on NetworkException {
      return const Left(NetworkFailure('No internet connection.'));
    } on NotFoundException catch (e) {
      return Left(ValidationFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
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
