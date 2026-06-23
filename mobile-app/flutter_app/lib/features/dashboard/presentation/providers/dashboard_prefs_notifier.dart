import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../features/authentication/presentation/providers/auth_notifier.dart';
import '../../domain/dashboard_prefs.dart';

final dashboardPrefsNotifierProvider =
    StateNotifierProvider<DashboardPrefsNotifier, DashboardPrefs>((ref) {
  final auth = ref.watch(authNotifierProvider);
  final username = auth is Authenticated ? auth.session.username : 'guest';
  return DashboardPrefsNotifier(username);
});

class DashboardPrefsNotifier extends StateNotifier<DashboardPrefs> {
  final String _username;

  DashboardPrefsNotifier(this._username) : super(DashboardPrefs.defaults) {
    _load();
  }

  String get _key => 'dashboard.prefs.$_username';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && mounted) {
      state = DashboardPrefs.fromJsonString(raw);
    }
  }

  Future<void> _persist(DashboardPrefs next) async {
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next.toJsonString());
  }

  Future<void> reorder(List<String> newOrder) =>
      _persist(state.copyWith(cardOrder: newOrder));

  Future<void> toggleVisibility(String cardId) {
    final hidden = Set<String>.from(state.hiddenCards);
    if (hidden.contains(cardId)) {
      hidden.remove(cardId);
    } else {
      hidden.add(cardId);
    }
    return _persist(state.copyWith(hiddenCards: hidden));
  }

  Future<void> toggleAction(String actionId) {
    final hidden = Set<String>.from(state.hiddenActions);
    if (hidden.contains(actionId)) {
      hidden.remove(actionId);
    } else {
      hidden.add(actionId);
    }
    return _persist(state.copyWith(hiddenActions: hidden));
  }

  Future<void> toggleCollapsed(String cardId) {
    final collapsed = Set<String>.from(state.collapsedCards);
    if (collapsed.contains(cardId)) {
      collapsed.remove(cardId);
    } else {
      collapsed.add(cardId);
    }
    return _persist(state.copyWith(collapsedCards: collapsed));
  }
}
