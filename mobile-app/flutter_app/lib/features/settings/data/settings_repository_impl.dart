import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  static const _apiUrlKey = 'bude.settings.api_url';
  final FlutterSecureStorage storage;

  SettingsRepositoryImpl({FlutterSecureStorage? storage})
      : storage = storage ?? const FlutterSecureStorage();

  @override
  Future<AppSettings> load() async {
    final url = await storage.read(key: _apiUrlKey);
    return AppSettings(apiBaseUrl: url);
  }

  @override
  Future<void> save(AppSettings settings) async {
    final url = settings.apiBaseUrl?.trim();
    if (url == null || url.isEmpty) {
      await storage.delete(key: _apiUrlKey);
    } else {
      await storage.write(key: _apiUrlKey, value: url);
    }
  }
}
