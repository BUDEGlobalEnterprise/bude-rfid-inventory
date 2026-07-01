import '../../../core/config/hr_api_endpoints.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/hr_api_client.dart';
import '../../../core/storage/secure_session_store.dart';

class AuthRepository {
  AuthRepository(this._client, this._sessionStore);

  final HrApiClient _client;
  final SecureSessionStore _sessionStore;

  Future<HrSession> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final response = await _client.post(
      baseUrl,
      HrApiEndpoints.login,
      data: {'usr': username, 'pwd': password},
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response,
      (value) => Map<String, dynamic>.from(value as Map),
    );
    if (!envelope.ok || envelope.data == null) {
      throw AuthFailure(envelope.message ?? 'Unable to sign in.');
    }
    final data = envelope.data!;
    final session = HrSession(
      baseUrl: baseUrl,
      user: data['user'] as String? ?? username,
      fullName: data['full_name'] as String? ?? username,
      apiKey: data['api_key'] as String? ?? '',
      apiSecret: data['api_secret'] as String? ?? '',
      roles: List<String>.from(data['roles'] as List? ?? const []),
    );
    if (!session.canUseHr) {
      throw AuthFailure('An HR role is required to use Bude HR.');
    }
    await _sessionStore.write(session);
    return session;
  }
}

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
}
