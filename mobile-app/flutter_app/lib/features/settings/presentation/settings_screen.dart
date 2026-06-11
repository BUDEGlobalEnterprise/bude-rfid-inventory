import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../authentication/presentation/providers/auth_notifier.dart';
import '../../tenant/presentation/providers/tenant_notifier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantState = ref.watch(tenantNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: switch (tenantState) {
          TenantActive(:final tenant) => _ActiveTenantView(tenant: tenant),
          TenantAbsent() => const _NoTenantView(),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _ActiveTenantView extends ConsumerWidget {
  final dynamic tenant; // Tenant — kept dynamic to avoid an extra import
  const _ActiveTenantView({required this.tenant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat.yMMMd();
    final branding = tenant.branding as Map<String, dynamic>?;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Current connection',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Company', value: tenant.companyName as String),
                _InfoRow(label: 'ERP URL', value: tenant.erpUrl as String),
                _InfoRow(
                  label: 'Connected since',
                  value: fmt.format((tenant.createdAt as DateTime).toLocal()),
                ),
                if (branding != null) ...[
                  const Divider(),
                  if (branding['erpnext_version'] != null)
                    _InfoRow(
                      label: 'ERPNext',
                      value: branding['erpnext_version'].toString(),
                    ),
                  if (branding['bude_api_version'] != null)
                    _InfoRow(
                      label: 'bude_api',
                      value: branding['bude_api_version'].toString(),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
          onPressed: () =>
              ref.read(authNotifierProvider.notifier).logout(),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.link_off),
          label: const Text('Reset connection'),
          onPressed: () => _confirmReset(context, ref),
        ),
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset connection?'),
        content: const Text(
          'This signs you out and removes the saved server. You will be sent back to setup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(authNotifierProvider.notifier).logout();
    await ref.read(tenantNotifierProvider.notifier).clearActive();
    if (!context.mounted) return;
    context.go('/onboarding');
  }
}

class _NoTenantView extends StatelessWidget {
  const _NoTenantView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No connection configured.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  GoRouter.of(context).go('/onboarding'),
              child: const Text('Set up now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
