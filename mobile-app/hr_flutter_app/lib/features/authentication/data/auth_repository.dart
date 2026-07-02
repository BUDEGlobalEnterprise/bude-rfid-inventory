import 'package:dio/dio.dart';

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
    await _validateEmployeeProfile(baseUrl);
    return session;
  }

  Future<void> _validateEmployeeProfile(String baseUrl) async {
    try {
      final response = await _client.get(baseUrl, HrApiEndpoints.profile);
      final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
        response,
        (value) => Map<String, dynamic>.from(value as Map? ?? const {}),
      );
      if (envelope.ok) return;
      await _sessionStore.clear();
      if (envelope.code == 'HR_EMPLOYEE_NOT_FOUND') {
        throw AuthFailure('No active Employee record is linked to this user.');
      }
      if (envelope.code == 'ENV_NO_FRAPPE') {
        throw AuthFailure('Bude HR API is not available on this site.');
      }
      throw AuthFailure(envelope.message ?? 'Unable to validate HR access.');
    } on DioException catch (error) {
      await _sessionStore.clear();
      if (error.response?.statusCode == 404) {
        throw AuthFailure('Bude HR API is not installed on this ERPNext site.');
      }
      rethrow;
    }
  }
}

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
}
