import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/use_case.dart';
import '../auth_repository.dart';

class ExpireSessionUseCase implements UseCase<void, NoParams> {
  final AuthRepository repository;

  ExpireSessionUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) {
    return repository.expireSession();
  }
}
