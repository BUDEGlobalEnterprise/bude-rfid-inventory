import 'package:flutter/material.dart';

/// Consistent empty-state placeholder for lists with no data.
class EmptyState extends StatelessWidget {
  const EmptyState({required this.message, this.icon, super.key});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
          ],
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Consistent error-state placeholder with a retry action.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Loading skeleton placeholder mimicking dashboard card layout.
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(height: 24, width: 200, color: color),
        const SizedBox(height: 16),
        _SkeletonCard(),
        const SizedBox(height: 12),
        _SkeletonCard(),
        const SizedBox(height: 12),
        _SkeletonCard(),
        const SizedBox(height: 12),
        _SkeletonCard(),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.filled(
            6,
            Container(width: 160, height: 112, color: color),
          ),
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 16, width: 150, color: color),
            const SizedBox(height: 12),
            Container(height: 12, width: double.infinity, color: color),
            const SizedBox(height: 4),
            Container(height: 12, width: 200, color: color),
          ],
        ),
      ),
    );
  }
}
