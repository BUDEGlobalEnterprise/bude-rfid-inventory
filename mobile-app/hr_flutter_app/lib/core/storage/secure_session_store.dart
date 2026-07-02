import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureSessionStoreProvider = Provider<SecureSessionStore>((ref) {
  return const SecureSessionStore();
});

class HrSession {
  final String baseUrl;
  final String user;
  final String fullName;
  final String apiKey;
  final String apiSecret;
  final List<String> roles;

  const HrSession({
    required this.baseUrl,
    required this.user,
    required this.fullName,
    required this.apiKey,
    required this.apiSecret,
    required this.roles,
  });

  bool get canUseHr =>
      user == 'Administrator' ||
      roles.any({'Employee', 'HR User', 'HR Manager', 'System Manager'}.contains);

  bool get isManager =>
      user == 'Administrator' ||
      roles.any({'HR Manager', 'HR User', 'System Manager'}.contains);
}

class SecureSessionStore {
  const SecureSessionStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  Future<HrSession?> read() async {
    final baseUrl = await _storage.read(key: 'base_url');
    final user = await _storage.read(key: 'user');
    final apiKey = await _storage.read(key: 'api_key');
    final apiSecret = await _storage.read(key: 'api_secret');
    if ([baseUrl, user, apiKey, apiSecret].any((value) => value == null)) {
      return null;
    }
    final roles = (await _storage.read(key: 'roles') ?? '')
        .split(',')
        .where((role) => role.trim().isNotEmpty)
        .toList();
    return HrSession(
      baseUrl: baseUrl!,
      user: user!,
      fullName: await _storage.read(key: 'full_name') ?? user,
      apiKey: apiKey!,
      apiSecret: apiSecret!,
      roles: roles,
    );
  }

  Future<void> write(HrSession session) async {
    await _storage.write(key: 'base_url', value: session.baseUrl);
    await _storage.write(key: 'user', value: session.user);
    await _storage.write(key: 'full_name', value: session.fullName);
    await _storage.write(key: 'api_key', value: session.apiKey);
    await _storage.write(key: 'api_secret', value: session.apiSecret);
    await _storage.write(key: 'roles', value: session.roles.join(','));
  }

  Future<void> clear() => _storage.deleteAll();
}
