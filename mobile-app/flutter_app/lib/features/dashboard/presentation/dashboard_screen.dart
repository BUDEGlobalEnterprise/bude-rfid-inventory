import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../authentication/presentation/providers/auth_notifier.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authNotifierProvider);
    final fullName =
        state is Authenticated ? (state.session.fullName ?? state.session.username) : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bude Inventory'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome, $fullName',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _NavCard(
                    icon: Icons.qr_code_scanner,
                    label: 'Scan',
                    onTap: () => context.push('/scan'),
                  ),
                  _NavCard(
                    icon: Icons.search,
                    label: 'Search Items',
                    onTap: () => context.push('/items'),
                  ),
                  const _NavCard(
                    icon: Icons.warehouse,
                    label: 'Warehouses',
                  ),
                  _NavCard(
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _NavCard({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Card(
      elevation: disabled ? 0 : 2,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: disabled ? Colors.grey : null),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(color: disabled ? Colors.grey : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
