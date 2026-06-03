import 'package:bude_inventory/core/errors/exceptions.dart';
import 'package:bude_inventory/core/errors/failures.dart';
import 'package:bude_inventory/features/authentication/data/auth_repository_impl.dart';
import 'package:bude_inventory/features/authentication/data/datasources/auth_local_data_source.dart';
import 'package:bude_inventory/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:bude_inventory/features/authentication/data/models/auth_session_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}

class _MockLocal extends Mock implements AuthLocalDataSource {}

class _FakeSessionModel extends Fake implements AuthSessionModel {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSessionModel());
  });

  late _MockRemote remote;
  late _MockLocal local;
  late AuthRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    local = _MockLocal();
    repo = AuthRepositoryImpl(remote: remote, local: local);
  });

  group('login', () {
    test('caches session and returns entity on success', () async {
      const model = AuthSessionModel(
        user: 'alice',
        apiKey: 'k',
        apiSecret: 's',
        fullName: 'Alice',
      );
      when(() => remote.login(username: 'alice', password: 'pw'))
          .thenAnswer((_) async => model);
      when(() => local.cacheSession(any())).thenAnswer((_) async {});

      final result = await repo.login(username: 'alice', password: 'pw');

      verify(() => local.cacheSession(model)).called(1);
      result.fold(
        (_) => fail('expected Right'),
        (session) {
          expect(session.username, 'alice');
          expect(session.token, 'k:s');
          expect(session.fullName, 'Alice');
        },
      );
    });

    test('maps AuthException to AuthFailure and does not cache', () async {
      when(() => remote.login(username: any(named: 'username'), password: any(named: 'password')))
          .thenThrow(const AuthException('bad creds'));

      final result = await repo.login(username: 'u', password: 'p');

      verifyNever(() => local.cacheSession(any()));
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps NetworkException to NetworkFailure', () async {
      when(() => remote.login(username: any(named: 'username'), password: any(named: 'password')))
          .thenThrow(const NetworkException('offline'));

      final result = await repo.login(username: 'u', password: 'p');

      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('logout', () {
    test('clears local cache even if remote logout fails', () async {
      when(() => remote.logout())
          .thenThrow(const NetworkException('offline'));
      when(() => local.clearSession()).thenAnswer((_) async {});

      final result = await repo.logout();

      verify(() => local.clearSession()).called(1);
      expect(result.isRight(), isTrue);
    });
  });

  group('currentSession', () {
    test('returns null when no cached session', () async {
      when(() => local.getCachedSession()).thenAnswer((_) async => null);
      final result = await repo.currentSession();
      result.fold(
        (_) => fail('expected Right'),
        (session) => expect(session, isNull),
      );
    });

    test('returns mapped entity when cached', () async {
      const model = AuthSessionModel(user: 'bob', apiKey: 'a', apiSecret: 'b');
      when(() => local.getCachedSession()).thenAnswer((_) async => model);
      final result = await repo.currentSession();
      result.fold(
        (_) => fail('expected Right'),
        (session) => expect(session?.username, 'bob'),
      );
    });
  });
}

