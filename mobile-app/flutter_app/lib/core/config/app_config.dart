import 'environment.dart';

class AppConfig {
  AppConfig._();

  static late Environment _env;
  static Environment get env => _env;

  static String get apiBaseUrl => _env.apiBaseUrl;
  static String get appName => _env.appName;
  static bool get isProduction => _env.isProduction;

  static Future<void> load({Environment? override}) async {
    _env = override ?? Environment.development();
  }
}
