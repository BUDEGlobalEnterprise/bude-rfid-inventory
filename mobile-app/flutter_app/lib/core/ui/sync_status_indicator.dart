import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../sync/providers.dart';
import '../utils/locale_ext.dart';

/// Compact AppBar action showing live sync state.
/// Replaces the plain badge+icon button on the dashboard.
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unresolvedOpCountProvider).valueOrNull ?? 0;

    final (IconData icon, String label, Color? color) = switch (count) {
      0 => (Icons.check_circle_outline, context.l10n.syncComplete, null),
      _ => (Icons.sync_problem_outlined, '$count', Theme.of(context).colorScheme.error),
    };

    return Tooltip(
      message: count == 0
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
              Icon(icon, size: 20, color: color),
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
