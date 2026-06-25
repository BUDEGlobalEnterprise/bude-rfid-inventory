import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/use_case.dart';
import '../auth_repository.dart';
import '../auth_session.dart';

/// Pulls fresh roles (and full name / default warehouse) from the backend for
/// the restored session. See [AuthRepository.refreshSession].
class RefreshSessionUseCase implements UseCase<AuthSession?, NoParams> {
  final AuthRepository repository;

  RefreshSessionUseCase(this.repository);

  @override
  Future<Either<Failure, AuthSession?>> call(NoParams params) {
    return repository.refreshSession();
  }
}
