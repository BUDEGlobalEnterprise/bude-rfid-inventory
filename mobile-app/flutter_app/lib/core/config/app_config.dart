import 'environment.dart';

class AppConfig {
  AppConfig._();

  static late Environment _env;
  static String? _apiBaseUrlOverride;

  static Environment get env => _env;

  static String get apiBaseUrl => _apiBaseUrlOverride ?? _env.apiBaseUrl;
  static String get appName => _env.appName;
  static bool get isProduction => _env.isProduction;

  static Future<void> load({Environment? override}) async {
    _env = override ?? Environment.development();
  }

  /// Override the API base URL at runtime (e.g. from persisted user settings).
  /// Pass null to revert to the environment default.
  static void setApiBaseUrlOverride(String? url) {
    final trimmed = url?.trim();
    _apiBaseUrlOverride = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
