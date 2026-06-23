import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppLockNotifier extends StateNotifier<bool> {
  AppLockNotifier() : super(false);

  void lock() => state = true;
  void unlock() => state = false;
}

final appLockProvider =
    StateNotifierProvider<AppLockNotifier, bool>((_) => AppLockNotifier());
