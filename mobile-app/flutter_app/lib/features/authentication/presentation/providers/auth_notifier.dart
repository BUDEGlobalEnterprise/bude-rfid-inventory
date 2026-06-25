import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/use_case.dart';
import '../../../settings/presentation/providers/settings_notifier.dart';
import '../../data/auth_repository_impl.dart';
import '../../data/datasources/auth_local_data_source.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_session.dart';
import '../../domain/usecases/get_current_session_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/refresh_session_usecase.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  final AuthSession session;
  const Authenticated(this.session);

  @override
  List<Object?> get props => [session];
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthFailed extends AuthState {
  final String message;
  const AuthFailed(this.message);

  @override
  List<Object?> get props => [message];
}

// --- Providers ---

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepositoryImpl(
    remote: AuthRemoteDataSourceImpl(apiClient.dio),
    local: AuthLocalDataSourceImpl(),
  );
});

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(
    loginUseCase: LoginUseCase(repo),
    logoutUseCase: LogoutUseCase(repo),
    getCurrentSessionUseCase: GetCurrentSessionUseCase(repo),
    refreshSessionUseCase: RefreshSessionUseCase(repo),
    apiClient: apiClient,
    ref: ref,
  );
});

/// Derived provider — empty set when unauthenticated.
final rolesProvider = Provider<Set<String>>((ref) {
  final authState = ref.watch(authNotifierProvider);
  if (authState is Authenticated) return authState.session.roles.toSet();
  return {};
});

class AuthNotifier extends StateNotifier<AuthState> {
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final GetCurrentSessionUseCase getCurrentSessionUseCase;
  final RefreshSessionUseCase refreshSessionUseCase;
  final ApiClient apiClient;
  final Ref _ref;

  AuthNotifier({
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.getCurrentSessionUseCase,
    required this.refreshSessionUseCase,
    required this.apiClient,
    required Ref ref,
  })  : _ref = ref,
        super(const AuthInitial());

  Future<void> bootstrap() async {
    state = const AuthLoading();
    final result = await getCurrentSessionUseCase(const NoParams());
    final cached = result.fold((_) => null, (session) => session);
    if (cached == null) {
      state = const Unauthenticated();
      return;
    }

    // Token must be set before session_info (it requires auth).
    apiClient.setAuthToken(cached.token);

    // Refresh roles from the backend so manager gating reflects the server,
    // not a stale/empty cached role list. Fall back to the cached session when
    // offline so the app still opens.
    final refreshed = await refreshSessionUseCase(const NoParams());
    final session = refreshed.fold((_) => cached, (s) => s ?? cached);

    _applyDefaultWarehouse(session);
    state = Authenticated(session);
  }

  Future<void> login(String username, String password) async {
    state = const AuthLoading();
    final result = await loginUseCase(
      LoginParams(username: username, password: password),
    );
    await result.fold(
      (failure) async {
        state = AuthFailed(failure.message);
      },
      (session) async {
        // Token must be active before session_info can refresh server roles.
        apiClient.setAuthToken(session.token);
        final refreshed = await refreshSessionUseCase(const NoParams());
        final effective = refreshed.fold((_) => session, (s) => s ?? session);
        _applyDefaultWarehouse(effective);
        state = Authenticated(effective);
      },
    );
  }

  Future<void> logout() async {
    await logoutUseCase(const NoParams());
    apiClient.clearAuthToken();
    state = const Unauthenticated();
  }

  void _applyDefaultWarehouse(AuthSession session) {
    final dw = session.defaultWarehouse;
    if (dw == null || dw.isEmpty) return;
    final settings = _ref.read(settingsNotifierProvider);
    if (settings.defaultSourceWarehouse == null) {
      _ref
          .read(settingsNotifierProvider.notifier)
          .setDefaultSourceWarehouse(dw);
    }
  }
}
