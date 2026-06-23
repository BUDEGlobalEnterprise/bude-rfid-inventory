import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../features/authentication/presentation/providers/auth_notifier.dart';
import '../../features/settings/presentation/providers/settings_notifier.dart';
import '../utils/locale_ext.dart';
import 'app_lock_notifier.dart';

class LockScreen extends ConsumerWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final username = authState is Authenticated
        ? (authState.session.fullName ?? authState.session.username)
        : '';
    final settings = ref.watch(settingsNotifierProvider);
    final threshold = settings.autoLogoutMinutes;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.sessionLocked,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                if (username.isNotEmpty) Chip(label: Text(username)),
                if (threshold > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Locked after $threshold min of inactivity',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 40),
                FilledButton.icon(
                  icon: const Icon(Icons.fingerprint),
                  label: Text(context.l10n.unlockApp),
                  onPressed: () => _unlock(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _unlock(BuildContext context, WidgetRef ref) async {
    final auth = LocalAuthentication();
    final bool authenticated = await auth.authenticate(
      localizedReason: context.l10n.unlockApp,
      options: const AuthenticationOptions(biometricOnly: false),
    );
    if (authenticated) {
      ref.read(appLockProvider.notifier).unlock();
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.approvalFailed)),
      );
    }
  }
}
