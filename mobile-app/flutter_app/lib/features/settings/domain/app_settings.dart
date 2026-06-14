import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class AppSettings extends Equatable {
  final String? apiBaseUrl;

  // Appearance
  final ThemeMode themeMode;
  final String? locale; // 'en' | 'ar' | null = system
  final bool highContrast;
  final double textScaleFactor; // 1.0 | 1.2 | 1.4

  // Defaults
  final String? defaultSourceWarehouse;
  final String? defaultTargetWarehouse;

  // Scanning
  final bool scanSound;
  final bool scanVibration;
  final bool continuousScanMode;

  // Security
  final int autoLogoutMinutes; // 0 = disabled

  // Sync
  final bool syncOnWifiOnly;
  final int syncIntervalMinutes; // 15 | 30 | 60

  // Recently used routes (most recent first, max 3)
  final List<String> recentRoutes;

  const AppSettings({
    this.apiBaseUrl,
    this.themeMode = ThemeMode.system,
    this.locale,
    this.highContrast = false,
    this.textScaleFactor = 1.0,
    this.defaultSourceWarehouse,
    this.defaultTargetWarehouse,
    this.scanSound = true,
    this.scanVibration = true,
    this.continuousScanMode = false,
    this.autoLogoutMinutes = 0,
    this.syncOnWifiOnly = false,
    this.syncIntervalMinutes = 30,
    this.recentRoutes = const [],
  });

  AppSettings copyWith({
    String? apiBaseUrl,
    ThemeMode? themeMode,
    Object? locale = _sentinel,
    bool? highContrast,
    double? textScaleFactor,
    Object? defaultSourceWarehouse = _sentinel,
    Object? defaultTargetWarehouse = _sentinel,
    bool? scanSound,
    bool? scanVibration,
    bool? continuousScanMode,
    int? autoLogoutMinutes,
    bool? syncOnWifiOnly,
    int? syncIntervalMinutes,
    List<String>? recentRoutes,
  }) {
    return AppSettings(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      themeMode: themeMode ?? this.themeMode,
      locale: locale == _sentinel ? this.locale : locale as String?,
      highContrast: highContrast ?? this.highContrast,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      defaultSourceWarehouse: defaultSourceWarehouse == _sentinel
          ? this.defaultSourceWarehouse
          : defaultSourceWarehouse as String?,
      defaultTargetWarehouse: defaultTargetWarehouse == _sentinel
          ? this.defaultTargetWarehouse
          : defaultTargetWarehouse as String?,
      scanSound: scanSound ?? this.scanSound,
      scanVibration: scanVibration ?? this.scanVibration,
      continuousScanMode: continuousScanMode ?? this.continuousScanMode,
      autoLogoutMinutes: autoLogoutMinutes ?? this.autoLogoutMinutes,
      syncOnWifiOnly: syncOnWifiOnly ?? this.syncOnWifiOnly,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      recentRoutes: recentRoutes ?? this.recentRoutes,
    );
  }

  @override
  List<Object?> get props => [
        apiBaseUrl,
        themeMode,
        locale,
        highContrast,
        textScaleFactor,
        defaultSourceWarehouse,
        defaultTargetWarehouse,
        scanSound,
        scanVibration,
        continuousScanMode,
        autoLogoutMinutes,
        syncOnWifiOnly,
        syncIntervalMinutes,
        recentRoutes,
      ];
}

// Sentinel used to distinguish "not passed" from "explicitly null".
const _sentinel = Object();
