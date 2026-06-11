import 'package:flutter/material.dart';

/// Themed error banner. Uses `colorScheme.errorContainer` /
/// `onErrorContainer` so it stays legible across light/dark themes and
/// adapts to whatever seed color the app is using.
class ErrorBanner extends StatelessWidget {
  final String message;
  final IconData icon;

  const ErrorBanner({
    super.key,
    required this.message,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: scheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline error text — for tile subtitles, validation messages, etc.
class ErrorText extends StatelessWidget {
  final String message;
  final int maxLines;
  final bool overflow;

  const ErrorText(
    this.message, {
    super.key,
    this.maxLines = 2,
    this.overflow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
      maxLines: maxLines,
      overflow: overflow ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }
}

/// Inline success text — green-ish via tertiary color so it works in both
/// material 3 dynamic and seed-based themes.
class SuccessText extends StatelessWidget {
  final String message;
  const SuccessText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Tertiary is the canonical "success/accent" slot in Material 3.
    return Text(
      message,
      style: TextStyle(color: scheme.tertiary),
    );
  }
}
