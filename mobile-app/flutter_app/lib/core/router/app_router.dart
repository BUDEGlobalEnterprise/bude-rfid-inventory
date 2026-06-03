import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/providers/auth_notifier.dart';
import '../../features/barcode/presentation/scanner_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/inventory/presentation/item_detail_screen.dart';
import '../../features/inventory/presentation/item_search_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/sync/presentation/pending_queue_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final loggedIn = authState is Authenticated;
      final location = state.matchedLocation;
      final publicRoute = location == '/login' || location == '/settings';

      if (authState is AuthInitial || authState is AuthLoading) {
        return null;
      }
      if (!loggedIn && !publicRoute) return '/login';
      if (loggedIn && location == '/login') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: '/items',
        builder: (context, state) => const ItemSearchScreen(),
      ),
      GoRoute(
        path: '/items/:code',
        builder: (context, state) => ItemDetailScreen(
          itemCode: Uri.decodeComponent(state.pathParameters['code']!),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/sync',
        builder: (context, state) => const PendingQueueScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(
      authNotifierProvider,
      (_, __) => notifyListeners(),
    );
  }
}
