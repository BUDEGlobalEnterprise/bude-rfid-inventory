import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/use_case.dart';
import '../../data/auth_repository_impl.dart';
import '../../data/datasources/auth_local_data_source.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_session.dart';
import '../../domain/usecases/get_current_session_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';

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
    apiClient: apiClient,
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final GetCurrentSessionUseCase getCurrentSessionUseCase;
  final ApiClient apiClient;

  AuthNotifier({
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.getCurrentSessionUseCase,
    required this.apiClient,
  }) : super(const AuthInitial());

  Future<void> bootstrap() async {
    state = const AuthLoading();
    final result = await getCurrentSessionUseCase(const NoParams());
    state = result.fold(
      (failure) => const Unauthenticated(),
      (session) {
        if (session == null) return const Unauthenticated();
        apiClient.setAuthToken(session.token);
        return Authenticated(session);
      },
    );
  }

  Future<void> login(String username, String password) async {
    state = const AuthLoading();
    final result = await loginUseCase(
      LoginParams(username: username, password: password),
    );
    state = result.fold(
      (failure) => AuthFailed(failure.message),
      (session) {
        apiClient.setAuthToken(session.token);
        return Authenticated(session);
      },
    );
  }

  Future<void> logout() async {
    await logoutUseCase(const NoParams());
    apiClient.clearAuthToken();
    state = const Unauthenticated();
  }
}
