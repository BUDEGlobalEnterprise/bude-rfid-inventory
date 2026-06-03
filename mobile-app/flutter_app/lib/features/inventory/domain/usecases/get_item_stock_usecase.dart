import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/use_case.dart';
import '../entities/item_stock.dart';
import '../repositories/item_repository.dart';

class GetItemStockParams extends Equatable {
  final String itemCode;
  final String? warehouse;

  const GetItemStockParams({required this.itemCode, this.warehouse});

  @override
  List<Object?> get props => [itemCode, warehouse];
}

class GetItemStockUseCase
    implements UseCase<List<ItemStock>, GetItemStockParams> {
  final ItemRepository repository;
  GetItemStockUseCase(this.repository);

  @override
  Future<Either<Failure, List<ItemStock>>> call(GetItemStockParams params) {
    return repository.getStock(
      params.itemCode,
      warehouse: params.warehouse,
    );
  }
}
