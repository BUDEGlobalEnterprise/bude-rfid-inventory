import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/use_case.dart';
import '../entities/item.dart';
import '../repositories/item_repository.dart';

class GetItemByBarcodeUseCase implements UseCase<Item, String> {
  final ItemRepository repository;
  GetItemByBarcodeUseCase(this.repository);

  @override
  Future<Either<Failure, Item>> call(String params) {
    return repository.getByBarcode(params);
  }
}
