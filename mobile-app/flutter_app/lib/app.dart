import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/network/auth_interceptor.dart';
import 'core/router/app_router.dart';
import 'core/sync/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/authentication/presentation/providers/auth_notifier.dart';
import 'features/receipt/data/receipt_op_submitter.dart';
import 'features/reconciliation/data/reconciliation_op_submitter.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final apiClient = ref.read(apiClientProvider);
      apiClient.installAuthInterceptor(
        AuthInterceptor(
          onUnauthorized: () =>
              ref.read(authNotifierProvider.notifier).logout(),
        ),
      );

      final engine = ref.read(syncEngineProvider);
      engine.registerSubmitter(TransferOpSubmitter(apiClient.dio));
      engine.registerSubmitter(ReceiptOpSubmitter(apiClient.dio));
      engine.registerSubmitter(ReconciliationOpSubmitter(apiClient.dio));
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
    );
  }
}
