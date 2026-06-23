import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/use_case.dart';
import '../entities/item.dart';
import '../repositories/item_repository.dart';

class SearchItemsParams extends Equatable {
  final String query;
  final int limit;
  final int page;
  final String? warehouse;
  final String? itemGroup;
  final bool inStock;

  const SearchItemsParams({
    required this.query,
    this.limit = 20,
    this.page = 0,
    this.warehouse,
    this.itemGroup,
    this.inStock = false,
  });

  @override
  List<Object?> get props => [query, limit, page, warehouse, itemGroup, inStock];
}

class SearchItemsUseCase implements UseCase<List<Item>, SearchItemsParams> {
  final ItemRepository repository;
  SearchItemsUseCase(this.repository);

  @override
  Future<Either<Failure, List<Item>>> call(SearchItemsParams params) {
    return repository.search(
      params.query,
      limit: params.limit,
      page: params.page,
      warehouse: params.warehouse,
      itemGroup: params.itemGroup,
      inStock: params.inStock,
    );
  }
}
