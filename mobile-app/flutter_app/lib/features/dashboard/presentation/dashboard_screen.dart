import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/providers.dart';
import '../../authentication/presentation/providers/auth_notifier.dart';
import '../../tenant/presentation/providers/tenant_notifier.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authNotifierProvider);
    final fullName = state is Authenticated
        ? (state.session.fullName ?? state.session.username)
        : '';
    final pendingCount = ref.watch(unresolvedOpCountProvider).valueOrNull ?? 0;
    final branding = ref.watch(currentBrandingProvider);
    final tenantState = ref.watch(tenantNotifierProvider);
    final tenantUrl =
        tenantState is TenantActive ? tenantState.tenant.erpUrl : null;
    final logoUrl = branding?.logoUrl(tenantUrl);
    final title = branding?.companyName ?? 'Bude Inventory';

    return Scaffold(
      appBar: AppBar(
        leading: logoUrl != null
            ? Padding(
                padding: const EdgeInsets.all(8),
                child: ClipOval(
                  child: Image.network(
                    logoUrl,
                    width: 32,
                    height: 32,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.inventory_2),
                  ),
                ),
              )
            : null,
        title: Text(title),
        actions: [
          _SyncBadgeButton(count: pendingCount),
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
                  _NavCard(
                    icon: Icons.swap_horiz,
                    label: 'Transfer',
                    onTap: () => context.push('/transfer'),
                  ),
                  _NavCard(
                    icon: Icons.input,
                    label: 'Receive',
                    onTap: () => context.push('/receipt'),
                  ),
                  _NavCard(
                    icon: Icons.fact_check,
                    label: 'Count',
                    onTap: () => context.push('/reconcile'),
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

class _SyncBadgeButton extends StatelessWidget {
  final int count;
  const _SyncBadgeButton({required this.count});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: count == 0 ? 'Sync (none pending)' : 'Sync ($count pending)',
      icon: Badge(
        label: count > 0 ? Text('$count') : null,
        isLabelVisible: count > 0,
        child: const Icon(Icons.sync),
      ),
      onPressed: () => context.push('/sync'),
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
