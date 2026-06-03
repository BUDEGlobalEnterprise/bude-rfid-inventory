import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/item.dart';
import '../entities/item_stock.dart';

abstract class ItemRepository {
  Future<Either<Failure, List<Item>>> search(String query, {int limit = 20});

  Future<Either<Failure, Item>> getByBarcode(String barcode);

  Future<Either<Failure, List<ItemStock>>> getStock(
    String itemCode, {
    String? warehouse,
  });
}
