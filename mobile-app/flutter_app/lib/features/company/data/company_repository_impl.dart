import 'package:dartz/dartz.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../domain/entities/company.dart';
import '../domain/repositories/company_repository.dart';
import 'datasources/company_remote_data_source.dart';

class CompanyRepositoryImpl implements CompanyRepository {
  final CompanyRemoteDataSource _remote;
  CompanyRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<Company>>> listCompanies({int limit = 50}) async {
    try {
      final models = await _remote.listCompanies(limit: limit);
      return Right(models.map((m) => m.toEntity()).toList());
    } on AuthException {
      return const Left(AuthFailure('Authentication required.'));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
