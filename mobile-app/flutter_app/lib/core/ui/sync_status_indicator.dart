import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../sync/pending_operation.dart';
import '../sync/providers.dart';
import '../utils/locale_ext.dart';

/// Compact AppBar action showing live sync state.
/// Replaces the plain badge+icon button on the dashboard.
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unresolvedOpCountProvider).valueOrNull ?? 0;
    final ops = ref.watch(allOpsProvider).valueOrNull ?? const [];
    final isSyncing = ops.any((o) => o.status == OpStatus.inflight);

    final scheme = Theme.of(context).colorScheme;

    final Widget icon;
    final String label;
    final Color? color;

    if (isSyncing) {
      icon = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: scheme.primary,
        ),
      );
      label = 'Syncing…';
      color = scheme.primary;
    } else if (count == 0) {
      icon = const Icon(Icons.check_circle_outline, size: 20);
      label = context.l10n.syncComplete;
      color = null;
    } else {
      icon = Icon(Icons.sync_problem_outlined, size: 20, color: scheme.error);
      label = '$count';
      color = scheme.error;
    }

    return Tooltip(
      message: isSyncing
          ? 'Syncing operations…'
          : count == 0
              ? context.l10n.syncNonePending
              : context.l10n.syncPending(count),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/sync'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
