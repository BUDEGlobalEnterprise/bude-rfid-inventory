import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/network/auth_interceptor.dart';
import 'core/router/app_router.dart';
import 'core/sync/providers.dart';
import 'features/authentication/presentation/providers/auth_notifier.dart';
import 'features/tenant/presentation/providers/tenant_notifier.dart';
import 'features/receipt/data/receipt_op_submitter.dart';
import 'features/transfer/data/transfer_op_submitter.dart';

class BudeInventoryApp extends ConsumerStatefulWidget {
  const BudeInventoryApp({super.key});

  @override
  ConsumerState<BudeInventoryApp> createState() => _BudeInventoryAppState();
}

class _BudeInventoryAppState extends ConsumerState<BudeInventoryApp> {
  ProviderSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Install the 401 interceptor immediately — safe to do before bootstrap
      // because the interceptor only fires on actual auth-failed responses.
      final apiClient = ref.read(apiClientProvider);
      apiClient.installAuthInterceptor(
        AuthInterceptor(
          onUnauthorized: () =>
              ref.read(authNotifierProvider.notifier).logout(),
        ),
      );

      // Register vendor-agnostic submitters with the sync engine before
      // starting it. New write features add their submitter here.
      final engine = ref.read(syncEngineProvider);
      engine.registerSubmitter(TransferOpSubmitter(apiClient.dio));
      engine.registerSubmitter(ReceiptOpSubmitter(apiClient.dio));
      engine.start();

      // On any successful login, mark the active tenant as used and refresh
      // its cached branding so the dashboard reflects the current customer.
      _authSub = ref.listenManual<AuthState>(authNotifierProvider, (
        prev,
        next,
      ) {
        if (next is Authenticated && prev is! Authenticated) {
          final tenantNotifier = ref.read(tenantNotifierProvider.notifier);
          tenantNotifier.markUsed();
          tenantNotifier.refreshBranding();
        }
      });
    });
  }

  @override
  void dispose() {
    _authSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
