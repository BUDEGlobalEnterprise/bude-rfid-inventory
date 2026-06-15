import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/providers/auth_notifier.dart';
import '../../features/barcode/presentation/scanner_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/inventory/presentation/item_detail_screen.dart';
import '../../features/inventory/presentation/item_search_screen.dart';
import '../../features/onboarding/presentation/company_setup_screen.dart';
import '../../features/receipt/presentation/receipt_screen.dart';
import '../../features/reconciliation/presentation/reconciliation_screen.dart';
import '../../features/scan_session/domain/scan_session_mode.dart';
import '../../features/scan_session/presentation/scan_session_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/sync/presentation/pending_queue_screen.dart';
import '../../features/tenant/presentation/providers/tenant_notifier.dart';
import '../../features/transfer/presentation/transfer_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/analytics/presentation/export_screen.dart';
import '../../features/analytics/presentation/stock_aging_screen.dart';
import '../../features/analytics/presentation/throughput_screen.dart';
import '../../features/analytics/presentation/variance_dashboard_screen.dart';
import '../../features/warehouse/presentation/warehouse_detail_screen.dart';
import '../../features/warehouse/presentation/warehouse_list_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final tenantState = ref.read(tenantNotifierProvider);
      final authState = ref.read(authNotifierProvider);
      final location = state.matchedLocation;

      // Until the tenant is resolved, don't redirect anywhere — splash drives.
      if (tenantState is TenantInitial || tenantState is TenantLoading) {
        return null;
      }

      // No tenant configured → must go through onboarding.
      if (tenantState is TenantAbsent) {
        if (location == '/splash' || location == '/onboarding') return null;
        return '/onboarding';
      }

      // Tenant exists.
      final loggedIn = authState is Authenticated;
      
      // If fully logged in, bounce them off splash, onboarding, and login.
      if (loggedIn) {
        if (location == '/splash' || location == '/onboarding' || location == '/login') {
          return '/';
        }
        return null;
      }

      // Not logged in (tenant exists).
      final publicRoute = location == '/login' || location == '/settings';
      if (authState is AuthInitial || authState is AuthLoading) return null;
      if (!publicRoute) return '/login';
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const CompanySetupScreen(),
      ),
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
      GoRoute(
        path: '/transfer',
        builder: (context, state) => const TransferScreen(),
      ),
      GoRoute(
        path: '/receipt',
        builder: (context, state) => const ReceiptScreen(),
      ),
      GoRoute(
        path: '/reconcile',
        builder: (context, state) => const ReconciliationScreen(),
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/analytics/aging',
        builder: (context, state) => const StockAgingScreen(),
      ),
      GoRoute(
        path: '/analytics/variance',
        builder: (context, state) => const VarianceDashboardScreen(),
      ),
      GoRoute(
        path: '/analytics/throughput',
        builder: (context, state) => const ThroughputScreen(),
      ),
      GoRoute(
        path: '/analytics/export',
        builder: (context, state) => const ExportScreen(),
      ),
      GoRoute(
        path: '/warehouses',
        builder: (context, state) => const WarehouseListScreen(),
      ),
      GoRoute(
        path: '/warehouse/:name',
        builder: (context, state) => WarehouseDetailScreen(
          warehouseName: Uri.decodeComponent(state.pathParameters['name']!),
        ),
      ),
      GoRoute(
        path: '/scan-session',
        builder: (context, state) => ScanSessionScreen(
          mode: ScanSessionModeExt.fromQuery(
            state.uri.queryParameters['mode'],
          ),
        ),
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
    ref.listen<TenantState>(
      tenantNotifierProvider,
      (_, __) => notifyListeners(),
    );
  }
}
