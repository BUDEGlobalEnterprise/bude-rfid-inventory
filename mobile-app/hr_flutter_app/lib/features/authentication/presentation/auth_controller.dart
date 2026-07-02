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
    try {
      state = state.copyWith(
        session: await _sessionStore.read(),
        isRestoring: false,
      );
    } catch (_) {
      state = state.copyWith(isRestoring: false);
    }
  }

  Future<void> login(String baseUrl, String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    final normalizedBaseUrl = normalizeBaseUrl(baseUrl);
    final trimmedUsername = username.trim();
    if (normalizedBaseUrl == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'Enter a valid ERPNext URL.',
      );
      return;
    }
    if (trimmedUsername.isEmpty || password.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Enter username and password.',
      );
      return;
    }
    try {
      final session = await _repository.login(
        baseUrl: normalizedBaseUrl,
        username: trimmedUsername,
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
    state = AuthState(isRestoring: false);
  }

  static String? normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) return null;
    if (trimmed.contains('://') &&
        !trimmed.startsWith('http://') &&
        !trimmed.startsWith('https://')) {
      return null;
    }
    final candidate =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? trimmed
            : 'https://$trimmed';
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return candidate.replaceFirst(RegExp(r'/+$'), '');
  }
}

class AuthState {
  AuthState({
    this.session,
    this.isLoading = false,
    this.isRestoring = true,
    this.error,
  });

  final HrSession? session;
  final bool isLoading;
  final bool isRestoring;
  final String? error;

  bool get isAuthenticated => session != null;

  AuthState copyWith({
    HrSession? session,
    bool? isLoading,
    bool? isRestoring,
    String? error,
  }) {
    return AuthState(
      session: session ?? this.session,
      isLoading: isLoading ?? this.isLoading,
      isRestoring: isRestoring ?? this.isRestoring,
      error: error,
    );
  }
}
