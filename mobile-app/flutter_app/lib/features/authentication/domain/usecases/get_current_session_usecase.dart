import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/use_case.dart';
import '../auth_repository.dart';
import '../auth_session.dart';

class GetCurrentSessionUseCase implements UseCase<AuthSession?, NoParams> {
  final AuthRepository repository;

  GetCurrentSessionUseCase(this.repository);

  @override
  Future<Either<Failure, AuthSession?>> call(NoParams params) {
    return repository.currentSession();
  }
}
