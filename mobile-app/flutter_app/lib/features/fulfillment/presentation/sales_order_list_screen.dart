import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/loading_shimmer.dart';
import '../../../core/ui/operational_components.dart';
import '../../../core/utils/locale_ext.dart';
import '../../transfer/presentation/providers/transfer_providers.dart';
import '../domain/sales_order.dart';
import 'providers/fulfillment_providers.dart';

class SalesOrderListScreen extends ConsumerWidget {
  const SalesOrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(salesOrderListProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.fulfillment)),
      body: ordersAsync.when(
        loading: () => const ShimmerList(count: 8),
        error: (e, _) => e is CompanySelectionRequiredException
            ? EmptyStateView(
                icon: Icons.business_outlined,
                title: context.l10n.selectCompany,
                subtitle: context.l10n.selectCompanyBeforeWarehouses,
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(e.toString(), textAlign: TextAlign.center),
                ),
              ),
        data: (orders) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(salesOrderListProvider),
          child: orders.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 120),
                    EmptyStateView(
                      icon: Icons.local_shipping_outlined,
                      title: context.l10n.noSalesOrders,
                      subtitle: context.l10n.noSalesOrdersSubtitle,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _SalesOrderTile(order: orders[index]);
                  },
                ),
        ),
      ),
    );
  }
}

class _SalesOrderTile extends StatelessWidget {
  final SalesOrderSummary order;
  const _SalesOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: ListTile(
        leading: const Icon(Icons.assignment_outlined),
        title: Text(order.name),
        subtitle: Text(
          [
            if (order.customer != null) order.customer,
            if (order.deliveryDate != null)
              context.l10n.dueDate(order.deliveryDate!),
            context.l10n.linesAndQty(
              order.itemCount,
              formatOperationalQty(order.pendingQty),
            ),
          ].whereType<String>().join(' - '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            context.push('/fulfillment/${Uri.encodeComponent(order.name)}'),
      ),
    );
  }
}
