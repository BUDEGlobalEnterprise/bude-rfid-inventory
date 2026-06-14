import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/presentation/providers/settings_notifier.dart';

/// Derived from [settingsNotifierProvider] so toggling in Settings updates
/// the entire app's theme without a restart.
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(
    settingsNotifierProvider.select((s) => s.themeMode),
  );
});

/// Current locale derived from settings.
final localeProvider = Provider<Locale?>((ref) {
  final code = ref.watch(
    settingsNotifierProvider.select((s) => s.locale),
  );
  if (code == null) return null;
  return Locale(code);
});
