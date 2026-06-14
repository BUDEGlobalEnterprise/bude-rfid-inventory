import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/providers.dart';
import '../utils/locale_ext.dart';

/// Streams connectivity state; emits true when any interface is up.
final _isOnlineProvider = StreamProvider<bool>((ref) {
  final info = ref.watch(networkInfoProvider);
  return info.onConnectivityChanged();
});

/// Sticky amber banner shown at the top of the screen when offline.
/// Zero-height when online — use inside a Column above the main body.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(_isOnlineProvider).valueOrNull ?? true;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: isOnline
          ? const SizedBox.shrink()
          : _Banner(message: context.l10n.offlineMessage),
    );
  }
}

class _Banner extends StatelessWidget {
  final String message;
  const _Banner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF9A825), // amber 800
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, size: 16, color: Colors.black87),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
