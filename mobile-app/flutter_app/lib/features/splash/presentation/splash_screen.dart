import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../authentication/presentation/providers/auth_notifier.dart';
import '../../tenant/presentation/providers/tenant_notifier.dart';

/// Initial route. Decides whether to send the user to `/onboarding`, `/login`,
/// or `/` based on tenant + auth state. Renders a fading logo while it
/// resolves — uses the cached tenant logo when available, falls back to a
/// generic icon otherwise.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                  CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
                ),
                child: Icon(
                  Icons.inventory_2,
                  size: 72,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
