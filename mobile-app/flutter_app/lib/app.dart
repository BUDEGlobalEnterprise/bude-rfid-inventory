import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/network/auth_interceptor.dart';
import 'core/router/app_router.dart';
import 'features/authentication/presentation/providers/auth_notifier.dart';
import 'features/settings/presentation/providers/settings_notifier.dart';

class BudeInventoryApp extends ConsumerStatefulWidget {
  const BudeInventoryApp({super.key});

  @override
  ConsumerState<BudeInventoryApp> createState() => _BudeInventoryAppState();
}

class _BudeInventoryAppState extends ConsumerState<BudeInventoryApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final apiClient = ref.read(apiClientProvider);
      apiClient.installAuthInterceptor(
        AuthInterceptor(
          onUnauthorized: () =>
              ref.read(authNotifierProvider.notifier).logout(),
        ),
      );
      // Settings first — sets the API base URL before any auth request fires.
      await ref.read(settingsNotifierProvider.notifier).bootstrap();
      await ref.read(authNotifierProvider.notifier).bootstrap();
    });
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
