import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import 'auth_session.dart';

abstract class AuthRepository {
  Future<Either<Failure, AuthSession>> login({
    required String username,
    required String password,
  });

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, AuthSession?>> currentSession();

  /// Validates a supervisor's credentials for second-user approval.
  /// Returns `(user, isSupervisor)` on success.
  Future<Either<Failure, (String, bool)>> validateSupervisor({
    required String username,
    required String password,
  });
}
