import 'package:dartz/dartz.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/logger.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import 'datasources/auth_local_data_source.dart';
import 'datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;

  AuthRepositoryImpl({required this.remote, required this.local});

  @override
  Future<Either<Failure, AuthSession>> login({
    required String username,
    required String password,
  }) async {
    try {
      final model = await remote.login(username: username, password: password);
      await local.cacheSession(model);
      return Right(model.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on CacheException catch (e) {
      appLogger.w('Login succeeded but cache failed: ${e.message}');
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      try {
        await remote.logout();
      } on Exception catch (e) {
        appLogger.w('Remote logout failed, clearing local anyway: $e');
      }
      await local.clearSession();
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, AuthSession?>> currentSession() async {
    try {
      final cached = await local.getCachedSession();
      return Right(cached?.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }
}
