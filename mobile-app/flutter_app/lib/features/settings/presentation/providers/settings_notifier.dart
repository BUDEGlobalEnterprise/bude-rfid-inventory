import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_repository_impl.dart';
import '../../domain/app_settings.dart';
import '../../domain/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(),
);

final settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(ref.read(settingsRepositoryProvider)),
);

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsRepository _repo;

  SettingsNotifier(this._repo) : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final loaded = await _repo.load();
    if (mounted) state = loaded;
  }

  Future<void> _persist(AppSettings next) async {
    state = next;
    await _repo.save(next);
  }

  Future<void> setApiBaseUrl(String? url) =>
      _persist(state.copyWith(apiBaseUrl: url));

  Future<void> setThemeMode(ThemeMode mode) =>
      _persist(state.copyWith(themeMode: mode));

  Future<void> setLocale(String? locale) =>
      _persist(state.copyWith(locale: locale));

  Future<void> setHighContrast(bool value) =>
      _persist(state.copyWith(highContrast: value));

  Future<void> setTextScaleFactor(double scale) =>
      _persist(state.copyWith(textScaleFactor: scale));

  Future<void> setDefaultSourceWarehouse(String? name) =>
      _persist(state.copyWith(defaultSourceWarehouse: name));

  Future<void> setDefaultTargetWarehouse(String? name) =>
      _persist(state.copyWith(defaultTargetWarehouse: name));

  Future<void> setScanSound(bool value) =>
      _persist(state.copyWith(scanSound: value));

  Future<void> setScanVibration(bool value) =>
      _persist(state.copyWith(scanVibration: value));

  Future<void> setContinuousScanMode(bool value) =>
      _persist(state.copyWith(continuousScanMode: value));

  Future<void> setAutoLogoutMinutes(int minutes) =>
      _persist(state.copyWith(autoLogoutMinutes: minutes));

  Future<void> setActiveCompany(String? name) =>
      _persist(state.copyWith(activeCompany: name));

  Future<void> setReconciliationVarianceThreshold(double threshold) =>
      _persist(state.copyWith(reconciliationVarianceThreshold: threshold));

  Future<void> setSyncOnWifiOnly(bool value) =>
      _persist(state.copyWith(syncOnWifiOnly: value));

  Future<void> setSyncIntervalMinutes(int minutes) =>
      _persist(state.copyWith(syncIntervalMinutes: minutes));

  Future<void> recordRouteVisit(String route) async {
    final updated = [
      route,
      ...state.recentRoutes.where((r) => r != route),
    ].take(3).toList();
    await _persist(state.copyWith(recentRoutes: updated));
  }
}
