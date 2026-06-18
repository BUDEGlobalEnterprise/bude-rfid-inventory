import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  // API URL stays in secure storage (was there before)
  static const _apiUrlKey = 'bude.settings.api_url';

  // All other prefs use shared_preferences
  static const _themeModeKey = 'app_settings.theme_mode';
  static const _localeKey = 'app_settings.locale';
  static const _highContrastKey = 'app_settings.high_contrast';
  static const _textScaleKey = 'app_settings.text_scale';
  static const _defSrcWhKey = 'app_settings.default_source_wh';
  static const _defTgtWhKey = 'app_settings.default_target_wh';
  static const _activeCompanyKey = 'app_settings.active_company';
  static const _varianceThresholdKey = 'app_settings.variance_threshold';
  static const _scanSoundKey = 'app_settings.scan_sound';
  static const _scanVibKey = 'app_settings.scan_vibration';
  static const _continuousScanKey = 'app_settings.continuous_scan';
  static const _autoLogoutKey = 'app_settings.auto_logout_minutes';
  static const _wifiOnlyKey = 'app_settings.sync_wifi_only';
  static const _syncIntervalKey = 'app_settings.sync_interval_minutes';
  static const _recentRoutesKey = 'app_settings.recent_routes';

  final FlutterSecureStorage _secure;

  SettingsRepositoryImpl({FlutterSecureStorage? storage})
      : _secure = storage ?? const FlutterSecureStorage();

  @override
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final url = await _secure.read(key: _apiUrlKey);

    final themeModeIndex = prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
    final locale = prefs.getString(_localeKey);
    final highContrast = prefs.getBool(_highContrastKey) ?? false;
    final textScale = prefs.getDouble(_textScaleKey) ?? 1.0;
    final defSrc = prefs.getString(_defSrcWhKey);
    final defTgt = prefs.getString(_defTgtWhKey);
    final activeCompany = prefs.getString(_activeCompanyKey);
    final varianceThreshold = prefs.getDouble(_varianceThresholdKey) ?? 0.0;
    final scanSound = prefs.getBool(_scanSoundKey) ?? true;
    final scanVib = prefs.getBool(_scanVibKey) ?? true;
    final contScan = prefs.getBool(_continuousScanKey) ?? false;
    final autoLogout = prefs.getInt(_autoLogoutKey) ?? 0;
    final wifiOnly = prefs.getBool(_wifiOnlyKey) ?? false;
    final syncInterval = prefs.getInt(_syncIntervalKey) ?? 30;
    final recentRoutes = prefs.getStringList(_recentRoutesKey) ?? [];

    return AppSettings(
      apiBaseUrl: url,
      themeMode: ThemeMode.values[themeModeIndex.clamp(0, ThemeMode.values.length - 1)],
      locale: locale,
      highContrast: highContrast,
      textScaleFactor: textScale,
      defaultSourceWarehouse: defSrc,
      defaultTargetWarehouse: defTgt,
      activeCompany: activeCompany,
      reconciliationVarianceThreshold: varianceThreshold,
      scanSound: scanSound,
      scanVibration: scanVib,
      continuousScanMode: contScan,
      autoLogoutMinutes: autoLogout,
      syncOnWifiOnly: wifiOnly,
      syncIntervalMinutes: syncInterval,
      recentRoutes: recentRoutes,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    // API URL stays in secure storage
    final url = settings.apiBaseUrl?.trim();
    if (url == null || url.isEmpty) {
      await _secure.delete(key: _apiUrlKey);
    } else {
      await _secure.write(key: _apiUrlKey, value: url);
    }

    await prefs.setInt(_themeModeKey, settings.themeMode.index);
    if (settings.locale != null) {
      await prefs.setString(_localeKey, settings.locale!);
    } else {
      await prefs.remove(_localeKey);
    }
    await prefs.setBool(_highContrastKey, settings.highContrast);
    await prefs.setDouble(_textScaleKey, settings.textScaleFactor);
    if (settings.defaultSourceWarehouse != null) {
      await prefs.setString(_defSrcWhKey, settings.defaultSourceWarehouse!);
    } else {
      await prefs.remove(_defSrcWhKey);
    }
    if (settings.defaultTargetWarehouse != null) {
      await prefs.setString(_defTgtWhKey, settings.defaultTargetWarehouse!);
    } else {
      await prefs.remove(_defTgtWhKey);
    }
    if (settings.activeCompany != null) {
      await prefs.setString(_activeCompanyKey, settings.activeCompany!);
    } else {
      await prefs.remove(_activeCompanyKey);
    }
    await prefs.setDouble(
        _varianceThresholdKey, settings.reconciliationVarianceThreshold,);
    await prefs.setBool(_scanSoundKey, settings.scanSound);
    await prefs.setBool(_scanVibKey, settings.scanVibration);
    await prefs.setBool(_continuousScanKey, settings.continuousScanMode);
    await prefs.setInt(_autoLogoutKey, settings.autoLogoutMinutes);
    await prefs.setBool(_wifiOnlyKey, settings.syncOnWifiOnly);
    await prefs.setInt(_syncIntervalKey, settings.syncIntervalMinutes);
    await prefs.setStringList(_recentRoutesKey, settings.recentRoutes);
  }
}
