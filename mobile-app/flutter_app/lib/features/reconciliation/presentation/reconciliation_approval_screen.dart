import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/sync/providers.dart';
import '../../../core/utils/locale_ext.dart';

class ReconciliationApprovalScreen extends ConsumerWidget {
  final String opId;
  const ReconciliationApprovalScreen({super.key, required this.opId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.approvalRequired)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.approval_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.approvalRequired,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.approvalRequiredSubtitle(
                _varianceSummary(ref, opId),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.fingerprint),
              label: Text(context.l10n.approveWithBiometric),
              onPressed: () => _approve(context, ref),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  String _varianceSummary(WidgetRef ref, String id) {
    final queue = ref.read(syncQueueProvider);
    final op = queue.getById(id);
    if (op == null) return '?';
    final payload = op.payload;
    final items = payload['items'] as List<dynamic>? ?? [];
    final total = items.fold<double>(0.0, (sum, item) {
      final diff = ((item as Map)['qty'] as num?)?.toDouble() ?? 0.0;
      return sum + diff.abs();
    });
    return total.toStringAsFixed(1);
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final auth = LocalAuthentication();
    final bool authenticated = await auth.authenticate(
      localizedReason: context.l10n.approveWithBiometric,
      options: const AuthenticationOptions(biometricOnly: false),
    );

    if (!context.mounted) return;

    if (authenticated) {
      await ref.read(syncQueueProvider).approve(opId);
      // ignore: discarded_futures
      ref.read(syncEngineProvider).kick();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.approvalGranted)),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.approvalFailed)),
      );
    }
  }
}
