import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/presentation/providers/auth_notifier.dart';
import '../../features/settings/presentation/providers/settings_notifier.dart';
import 'app_lock_notifier.dart';

class InactivityObserver extends WidgetsBindingObserver {
  final WidgetRef _ref;
  DateTime? _backgroundedAt;

  InactivityObserver(this._ref); // WidgetRef from ConsumerState

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final bg = _backgroundedAt;
      if (bg == null) return;

      final settings = _ref.read(settingsNotifierProvider);
      final threshold = settings.autoLogoutMinutes;
      if (threshold <= 0) return;

      final elapsed = DateTime.now().difference(bg).inMinutes;
      if (elapsed >= threshold) {
        final authState = _ref.read(authNotifierProvider);
        if (authState is Authenticated) {
          _ref.read(appLockProvider.notifier).lock();
        }
      }
    }
  }
}
