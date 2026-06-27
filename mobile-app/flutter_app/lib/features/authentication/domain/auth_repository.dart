import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import 'auth_session.dart';

abstract class AuthRepository {
  Future<Either<Failure, AuthSession>> login({
    required String username,
    required String password,
  });

  Future<Either<Failure, void>> logout();

  /// Clears local credentials without calling the backend. Used when the
  /// server has already rejected the token with 401/403.
  Future<Either<Failure, void>> expireSession();

  Future<Either<Failure, AuthSession?>> currentSession();

  /// Refreshes the cached session's roles / full name / default warehouse from
  /// the backend (`auth.session_info`). Returns the cached api keys merged with
  /// the server's fresh role list, and re-caches it. Requires the auth token to
  /// already be set on the client.
  Future<Either<Failure, AuthSession?>> refreshSession();

  /// Validates a supervisor's credentials for second-user approval.
  /// Returns `(user, isSupervisor)` on success.
  Future<Either<Failure, (String, bool)>> validateSupervisor({
    required String username,
    required String password,
  });
}
