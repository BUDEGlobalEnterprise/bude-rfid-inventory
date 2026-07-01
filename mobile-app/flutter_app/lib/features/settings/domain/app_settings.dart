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
  final String? activeCompany;
  final double reconciliationVarianceThreshold; // 0.0 = disabled
  final double transferApprovalQtyThreshold; // 0.0 = disabled

  // Scanning
  final bool scanSound;
  final bool scanVibration;
  final bool continuousScanMode;

  // Security
  final int autoLogoutMinutes; // 0 = disabled

  // Sync
  final bool syncOnWifiOnly;
  final int syncIntervalMinutes; // 15 | 30 | 60

  // Search filter persistence
  final String? lastSearchWarehouse;
  final String? lastSearchItemGroup;
  final bool lastSearchInStock;

  const AppSettings({
    this.apiBaseUrl,
    this.themeMode = ThemeMode.system,
    this.locale,
    this.highContrast = false,
    this.textScaleFactor = 1.0,
    this.defaultSourceWarehouse,
    this.defaultTargetWarehouse,
    this.activeCompany,
    this.reconciliationVarianceThreshold = 0.0,
    this.transferApprovalQtyThreshold = 0.0,
    this.scanSound = true,
    this.scanVibration = true,
    this.continuousScanMode = false,
    this.autoLogoutMinutes = 0,
    this.syncOnWifiOnly = false,
    this.syncIntervalMinutes = 30,
    this.lastSearchWarehouse,
    this.lastSearchItemGroup,
    this.lastSearchInStock = false,
  });

  AppSettings copyWith({
    String? apiBaseUrl,
    ThemeMode? themeMode,
    Object? locale = _sentinel,
    bool? highContrast,
    double? textScaleFactor,
    Object? defaultSourceWarehouse = _sentinel,
    Object? defaultTargetWarehouse = _sentinel,
    Object? activeCompany = _sentinel,
    double? reconciliationVarianceThreshold,
    double? transferApprovalQtyThreshold,
    bool? scanSound,
    bool? scanVibration,
    bool? continuousScanMode,
    int? autoLogoutMinutes,
    bool? syncOnWifiOnly,
    int? syncIntervalMinutes,
    Object? lastSearchWarehouse = _sentinel,
    Object? lastSearchItemGroup = _sentinel,
    bool? lastSearchInStock,
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
      activeCompany: activeCompany == _sentinel
          ? this.activeCompany
          : activeCompany as String?,
      reconciliationVarianceThreshold: reconciliationVarianceThreshold ??
          this.reconciliationVarianceThreshold,
      transferApprovalQtyThreshold:
          transferApprovalQtyThreshold ?? this.transferApprovalQtyThreshold,
      scanSound: scanSound ?? this.scanSound,
      scanVibration: scanVibration ?? this.scanVibration,
      continuousScanMode: continuousScanMode ?? this.continuousScanMode,
      autoLogoutMinutes: autoLogoutMinutes ?? this.autoLogoutMinutes,
      syncOnWifiOnly: syncOnWifiOnly ?? this.syncOnWifiOnly,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      lastSearchWarehouse: lastSearchWarehouse == _sentinel
          ? this.lastSearchWarehouse
          : lastSearchWarehouse as String?,
      lastSearchItemGroup: lastSearchItemGroup == _sentinel
          ? this.lastSearchItemGroup
          : lastSearchItemGroup as String?,
      lastSearchInStock: lastSearchInStock ?? this.lastSearchInStock,
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
        activeCompany,
        reconciliationVarianceThreshold,
        transferApprovalQtyThreshold,
        scanSound,
        scanVibration,
        continuousScanMode,
        autoLogoutMinutes,
        syncOnWifiOnly,
        syncIntervalMinutes,
        lastSearchWarehouse,
        lastSearchItemGroup,
        lastSearchInStock,
      ];
}

// Sentinel used to distinguish "not passed" from "explicitly null".
const _sentinel = Object();
