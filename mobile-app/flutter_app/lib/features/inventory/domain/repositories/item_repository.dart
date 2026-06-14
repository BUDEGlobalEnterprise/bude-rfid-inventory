import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/item.dart';
import '../entities/item_stock.dart';
import '../entities/stock_ledger_entry.dart';

abstract class ItemRepository {
  Future<Either<Failure, List<Item>>> search(String query, {int limit = 20});

  Future<Either<Failure, Item>> getByBarcode(String barcode);

  Future<Either<Failure, List<ItemStock>>> getStock(
    String itemCode, {
    String? warehouse,
  });

  Future<Either<Failure, List<StockLedgerEntry>>> getLedger(
    String itemCode, {
    String? warehouse,
    int limit = 50,
  });
}
