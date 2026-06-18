import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/company.dart';

abstract class CompanyRepository {
  Future<Either<Failure, List<Company>>> listCompanies({int limit = 50});
}
