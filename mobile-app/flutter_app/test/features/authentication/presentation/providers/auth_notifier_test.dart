import 'package:bude_inventory/core/errors/failures.dart';
import 'package:bude_inventory/core/network/api_client.dart';
import 'package:bude_inventory/features/authentication/domain/auth_repository.dart';
import 'package:bude_inventory/features/authentication/domain/auth_session.dart';
import 'package:bude_inventory/features/authentication/presentation/providers/auth_notifier.dart';
import 'package:bude_inventory/features/settings/domain/app_settings.dart';
import 'package:bude_inventory/features/settings/domain/settings_repository.dart';
import 'package:bude_inventory/features/settings/presentation/providers/settings_notifier.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repo;

  setUp(() {
    repo = _MockAuthRepository();
  });

  test('login publishes roles refreshed from session_info', () async {
    when(() => repo.login(username: 'alice', password: 'pw')).thenAnswer(
      (_) async => const Right(
        AuthSession(username: 'alice', token: 'k:s', roles: []),
      ),
    );
    when(() => repo.refreshSession()).thenAnswer(
      (_) async => const Right(
        AuthSession(
          username: 'alice',
          token: 'k:s',
          roles: ['Stock Manager'],
        ),
      ),
    );

    final apiClient = ApiClient(dio: Dio());
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        authRepositoryProvider.overrideWithValue(repo),
        settingsNotifierProvider.overrideWith(
          (ref) => _SettingsNotifierForTest(const AppSettings()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authNotifierProvider.notifier).login('alice', 'pw');

    final state = container.read(authNotifierProvider);
    expect(state, isA<Authenticated>());
    expect((state as Authenticated).session.roles, ['Stock Manager']);
    expect(container.read(rolesProvider), {'Stock Manager'});
    expect(apiClient.dio.options.headers['Authorization'], 'token k:s');
    verify(() => repo.login(username: 'alice', password: 'pw')).called(1);
    verify(() => repo.refreshSession()).called(1);
  });

  test('login falls back to login session when role refresh fails', () async {
    when(() => repo.login(username: 'alice', password: 'pw')).thenAnswer(
      (_) async => const Right(
        AuthSession(
          username: 'alice',
          token: 'k:s',
          roles: ['Stock User'],
        ),
      ),
    );
    when(() => repo.refreshSession()).thenAnswer(
      (_) async => const Left(NetworkFailure('offline')),
    );

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(ApiClient(dio: Dio())),
        authRepositoryProvider.overrideWithValue(repo),
        settingsNotifierProvider.overrideWith(
          (ref) => _SettingsNotifierForTest(const AppSettings()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authNotifierProvider.notifier).login('alice', 'pw');

    final state = container.read(authNotifierProvider);
    expect(state, isA<Authenticated>());
    expect((state as Authenticated).session.roles, ['Stock User']);
  });
}

class _SettingsNotifierForTest extends SettingsNotifier {
  _SettingsNotifierForTest(AppSettings settings)
      : super(_SettingsRepositoryForTest(settings)) {
    state = settings;
  }
}

class _SettingsRepositoryForTest implements SettingsRepository {
  AppSettings settings;

  _SettingsRepositoryForTest(this.settings);

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async {
    this.settings = settings;
  }
}
