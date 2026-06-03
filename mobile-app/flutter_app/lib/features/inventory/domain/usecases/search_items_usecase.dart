import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/use_case.dart';
import '../entities/item.dart';
import '../repositories/item_repository.dart';

class SearchItemsParams extends Equatable {
  final String query;
  final int limit;

  const SearchItemsParams({required this.query, this.limit = 20});

  @override
  List<Object?> get props => [query, limit];
}

class SearchItemsUseCase implements UseCase<List<Item>, SearchItemsParams> {
  final ItemRepository repository;
  SearchItemsUseCase(this.repository);

  @override
  Future<Either<Failure, List<Item>>> call(SearchItemsParams params) {
    return repository.search(params.query, limit: params.limit);
  }
}
