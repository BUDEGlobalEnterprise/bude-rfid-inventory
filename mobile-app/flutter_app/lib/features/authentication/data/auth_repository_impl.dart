import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

class AuthRepositoryImpl implements AuthRepository {
  @override
  Future<Either<Failure, AuthSession>> login({
    required String username,
    required String password,
  }) async {
    return const Left(AuthFailure('Not implemented in Phase 1'));
  }

  @override
  Future<Either<Failure, void>> logout() async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, AuthSession?>> currentSession() async {
    return const Right(null);
  }
}
