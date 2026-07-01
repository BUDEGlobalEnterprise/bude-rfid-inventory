import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/hr_api_client.dart';
import '../../../core/storage/secure_session_store.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(hrApiClientProvider),
    ref.watch(secureSessionStoreProvider),
  );
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(authRepositoryProvider),
    ref.watch(secureSessionStoreProvider),
  )..restore();
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository, this._sessionStore) : super(AuthState());

  final AuthRepository _repository;
  final SecureSessionStore _sessionStore;

  Future<void> restore() async {
    state = state.copyWith(session: await _sessionStore.read());
  }

  Future<void> login(String baseUrl, String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final session = await _repository.login(
        baseUrl: _normalizeBaseUrl(baseUrl),
        username: username.trim(),
        password: password,
      );
      state = state.copyWith(isLoading: false, session: session);
    } on AuthFailure catch (error) {
      state = state.copyWith(isLoading: false, error: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Unable to reach ERPNext.',
      );
    }
  }

  Future<void> signOut() async {
    await _sessionStore.clear();
    state = AuthState();
  }

  String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed.replaceFirst(RegExp(r'/$'), '');
    }
    return 'https://$trimmed';
  }
}

class AuthState {
  AuthState({this.session, this.isLoading = false, this.error});

  final HrSession? session;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => session != null;

  AuthState copyWith({
    HrSession? session,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      session: session ?? this.session,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
