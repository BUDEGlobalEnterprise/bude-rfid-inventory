import 'package:bude_inventory/core/errors/failures.dart';
import 'package:bude_inventory/features/authentication/domain/auth_repository.dart';
import 'package:bude_inventory/features/authentication/domain/auth_session.dart';
import 'package:bude_inventory/features/authentication/domain/usecases/login_usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repo;
  late LoginUseCase useCase;

  setUp(() {
    repo = _MockAuthRepository();
    useCase = LoginUseCase(repo);
  });

  test('forwards credentials to repository and returns its result', () async {
    const session = AuthSession(username: 'alice', token: 'k:s');
    when(() => repo.login(username: 'alice', password: 'hunter2'))
        .thenAnswer((_) async => const Right(session));

    final result =
        await useCase(const LoginParams(username: 'alice', password: 'hunter2'));

    expect(result, const Right<Failure, AuthSession>(session));
    verify(() => repo.login(username: 'alice', password: 'hunter2')).called(1);
  });

  test('propagates failures unchanged', () async {
    when(() => repo.login(username: any(named: 'username'), password: any(named: 'password')))
        .thenAnswer((_) async => const Left(AuthFailure('bad creds')));

    final result =
        await useCase(const LoginParams(username: 'u', password: 'p'));

    expect(result.isLeft(), isTrue);
    result.fold(
      (f) => expect(f, isA<AuthFailure>().having((e) => e.message, 'message', 'bad creds')),
      (_) => fail('expected Left'),
    );
  });
}
