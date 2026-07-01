import '../../../core/config/hr_api_endpoints.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/hr_api_client.dart';
import '../../../core/storage/secure_session_store.dart';

class NotificationRepository {
  NotificationRepository(this._client, this._sessionStore);

  final HrApiClient _client;
  final SecureSessionStore _sessionStore;

  Future<List<HrNotification>> list() async {
    final session = await _sessionStore.read();
    if (session == null) return const [];
    final response = await _client.get(session.baseUrl, HrApiEndpoints.notifications);
    final envelope = ApiEnvelope<List<dynamic>>.fromJson(
      response,
      (value) => List<dynamic>.from(value as List? ?? const []),
    );
    return (envelope.data ?? const [])
        .map((row) => HrNotification.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }
}

class HrNotification {
  final String title;
  final String message;
  final String date;

  const HrNotification({
    required this.title,
    required this.message,
    required this.date,
  });

  factory HrNotification.fromJson(Map<String, dynamic> json) {
    return HrNotification(
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      date: json['date'] as String? ?? '',
    );
  }
}
