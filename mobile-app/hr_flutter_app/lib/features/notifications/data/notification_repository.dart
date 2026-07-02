import '../../../core/config/hr_api_endpoints.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/hr_api_client.dart';
import '../../../core/offline/read_cache.dart';
import '../../../core/storage/secure_session_store.dart';

class NotificationRepository {
  NotificationRepository(this._client, this._sessionStore, [ReadCache? cache])
      : _cache = cache ?? ReadCache();

  final HrApiClient _client;
  final SecureSessionStore _sessionStore;
  final ReadCache _cache;

  Future<Cached<List<HrNotification>>> list() async {
    final session = await _sessionStore.read();
    if (session == null) return Cached(const [], DateTime.now());
    return cacheThrough(
      cache: _cache,
      key: 'notifications',
      fetchRaw: () async {
        final response =
            await _client.get(session.baseUrl, HrApiEndpoints.notifications);
        final envelope = ApiEnvelope<List<dynamic>>.fromJson(
          response,
          (value) => List<dynamic>.from(value as List? ?? const []),
        );
        return envelope.data ?? const [];
      },
      parse: (raw) => (raw as List)
          .map((row) =>
              HrNotification.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(),
    );
  }

  Future<HrNotification> detail(String name) async {
    final session = await _sessionStore.read();
    if (session == null) throw StateError('Not signed in.');
    final response = await _client.get(
      session.baseUrl,
      HrApiEndpoints.notificationDetail,
      query: {'name': name},
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response,
      (value) => Map<String, dynamic>.from(value as Map? ?? const {}),
    );
    if (!envelope.ok || envelope.data == null) {
      throw Exception(envelope.message ?? 'Unable to load notification.');
    }
    return HrNotification.fromJson(envelope.data!);
  }

  Future<void> markRead(String name) async {
    final session = await _sessionStore.read();
    if (session == null) return;
    await _client.post(
      session.baseUrl,
      HrApiEndpoints.markNotificationRead,
      data: {'name': name},
    );
  }
}

class HrNotification {
  final String name;
  final String title;
  final String message;
  final String date;
  final bool read;

  const HrNotification({
    required this.name,
    required this.title,
    required this.message,
    required this.date,
    required this.read,
  });

  factory HrNotification.fromJson(Map<String, dynamic> json) {
    return HrNotification(
      name: json['name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      date: json['date'] as String? ?? '',
      read: json['read'] == true,
    );
  }
}
