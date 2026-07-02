import 'package:flutter/material.dart';

/// Small caption showing when cached read-only data was last refreshed, and
/// an "offline" hint when the shown data came from the cache. Takes the
/// primitive fields (not `Cached<T>`) so it works for any cached payload.
class LastRefreshedLabel extends StatelessWidget {
  const LastRefreshedLabel({
    required this.fetchedAt,
    required this.fromCache,
    super.key,
  });

  final DateTime fetchedAt;
  final bool fromCache;

  @override
  Widget build(BuildContext context) {
    final when = fetchedAt.toLocal();
    final stamp = '${when.year.toString().padLeft(4, '0')}-'
        '${when.month.toString().padLeft(2, '0')}-'
        '${when.day.toString().padLeft(2, '0')} '
        '${when.hour.toString().padLeft(2, '0')}:'
        '${when.minute.toString().padLeft(2, '0')}';
    final text = fromCache ? 'Offline · last updated $stamp' : 'Updated $stamp';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(
            fromCache ? Icons.cloud_off : Icons.check_circle_outline,
            size: 14,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
