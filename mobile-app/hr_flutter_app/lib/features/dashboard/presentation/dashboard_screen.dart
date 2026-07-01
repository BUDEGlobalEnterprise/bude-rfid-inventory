import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../authentication/presentation/auth_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bude HR'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Hello, ${session?.fullName ?? 'Employee'}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _ActionCard('/attendance', Icons.fingerprint, 'Attendance'),
              _ActionCard('/leave', Icons.event_available, 'Leave'),
              _ActionCard('/expenses', Icons.receipt_long, 'Expenses'),
              _ActionCard('/salary', Icons.payments, 'Salary'),
              _ActionCard('/profile', Icons.badge, 'Profile'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(this.route, this.icon, this.label);

  final String route;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 112,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 28),
                Text(label, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
