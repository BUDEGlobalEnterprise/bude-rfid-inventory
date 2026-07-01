import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/app_lock_notifier.dart';
import 'core/auth/inactivity_observer.dart';
import 'core/auth/lock_screen.dart';
import 'core/constants/app_strings.dart';
import 'core/network/auth_interceptor.dart';
import 'core/router/app_router.dart';
import 'core/sync/providers.dart';
import 'core/sync/pending_operation.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/assets/data/asset_op_submitters.dart';
import 'features/authentication/presentation/providers/auth_notifier.dart';
import 'features/fulfillment/data/sales_order_dispatch_op_submitter.dart';
import 'features/receipt/data/receipt_op_submitter.dart';
import 'features/reconciliation/data/reconciliation_op_submitter.dart';
import 'features/tasks/data/warehouse_task_remote_data_source.dart';
import 'features/tenant/presentation/providers/tenant_notifier.dart';
import 'features/transfer/data/transfer_op_submitter.dart';
import 'l10n/app_localizations.dart';

class BudeInventoryApp extends ConsumerStatefulWidget {
  const BudeInventoryApp({super.key});

  @override
  ConsumerState<BudeInventoryApp> createState() => _BudeInventoryAppState();
}

class _BudeInventoryAppState extends ConsumerState<BudeInventoryApp> {
  ProviderSubscription<AuthState>? _authSub;
  late final InactivityObserver _inactivityObserver;

  @override
  void initState() {
    super.initState();
    _inactivityObserver = InactivityObserver(ref);
    WidgetsBinding.instance.addObserver(_inactivityObserver);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final apiClient = ref.read(apiClientProvider);
      apiClient.installAuthInterceptor(
        AuthInterceptor(
          onUnauthorized: () =>
              ref.read(authNotifierProvider.notifier).expireSession(),
        ),
      );

      final engine = ref.read(syncEngineProvider);
      engine.registerSubmitter(TransferOpSubmitter(apiClient.dio));
      engine.registerSubmitter(ReceiptOpSubmitter(apiClient.dio));
      engine.registerSubmitter(ReconciliationOpSubmitter(apiClient.dio));
      engine.registerSubmitter(SalesOrderDispatchOpSubmitter(apiClient.dio));
      engine.registerSubmitter(AssetMovementOpSubmitter(apiClient.dio));
      engine.registerSubmitter(AssetRepairOpSubmitter(apiClient.dio));
      engine.registerSubmitter(MaintenanceLogOpSubmitter(apiClient.dio));
      final taskRemote = WarehouseTaskRemoteDataSource(apiClient.dio);
      engine.registerSuccessHook((op, serverRef) async {
        final todoName = op.payload['todo_name'];
        if (todoName is! String || todoName.trim().isEmpty) return;
        await taskRemote.complete(
          todoName: todoName,
          resultDoctype: _resultDoctypeForOp(op),
          resultName: serverRef,
        );
      });
      engine.start();

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
    WidgetsBinding.instance.removeObserver(_inactivityObserver);
    _authSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        final locked = ref.watch(appLockProvider);
        return Stack(
          children: [
            child!,
            if (locked) const LockScreen(),
          ],
        );
      },
    );
  }
}

String? _resultDoctypeForOp(PendingOperation op) {
  return switch (op.type) {
    kStockReceiptOpType => op.payload['against_po'] == null
        ? 'Stock Entry'
        : 'Purchase Receipt',
    kSalesOrderDispatchOpType => 'Delivery Note',
    kMaintenanceLogOpType => 'Asset Maintenance Log',
    kStockTransferOpType => 'Stock Entry',
    kStockReconciliationOpType => 'Stock Reconciliation',
    _ => null,
  };
}
