/// Public version surface for the app. Keep in sync with pubspec.yaml's
/// `version:` line and the release date when we cut builds.
class AppVersion {
  AppVersion._();

  /// Marketing version — matches `version:` in pubspec.yaml.
  static const String version = '0.1.0';

  /// Release date for the current build (ISO date string, no time).
  static const String releaseDate = '2026-06-11';

  /// Single-line footer label used by SplashScreen + onboarding + settings.
  static String get footer => 'v$version  ·  Released $releaseDate';
}
