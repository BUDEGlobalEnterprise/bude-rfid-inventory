import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/warehouse_stock_line.dart';

abstract class WarehouseRepository {
  Future<Either<Failure, List<String>>> listWarehouses({
    int limit = 100,
    String? company,
  });

  Future<Either<Failure, List<WarehouseStockLine>>> getStock(
    String warehouse, {
    int limit = 100,
  });
}
