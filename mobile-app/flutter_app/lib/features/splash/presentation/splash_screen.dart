import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../authentication/presentation/providers/auth_notifier.dart';
import '../../tenant/presentation/providers/tenant_notifier.dart';

/// Initial route. Decides whether to send the user to `/onboarding`, `/login`,
/// or `/` based on tenant + auth state. Renders a centered logo placeholder
/// while it resolves.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    await ref.read(tenantNotifierProvider.notifier).bootstrap();
    if (!mounted) return;

    final tenant = ref.read(tenantNotifierProvider);
    if (tenant is TenantAbsent) {
      _go('/onboarding');
      return;
    }

    await ref.read(authNotifierProvider.notifier).bootstrap();
    if (!mounted) return;

    final auth = ref.read(authNotifierProvider);
    _go(auth is Authenticated ? '/' : '/login');
  }

  void _go(String path) {
    if (_routed) return;
    _routed = true;
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
