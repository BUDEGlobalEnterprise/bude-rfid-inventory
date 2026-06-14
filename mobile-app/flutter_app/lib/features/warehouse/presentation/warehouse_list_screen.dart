import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/loading_shimmer.dart';
import '../../../core/utils/locale_ext.dart';
import 'providers/warehouse_providers.dart';

class WarehouseListScreen extends ConsumerWidget {
  const WarehouseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehousesAsync = ref.watch(warehouseListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.warehouses)),
      body: warehousesAsync.when(
        loading: () => const ShimmerList(count: 10),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.l10n.failedToLoadWarehouses(e.toString()),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (names) => names.isEmpty
            ? EmptyStateView(
                icon: Icons.warehouse_outlined,
                title: context.l10n.noWarehousesFound,
                subtitle: context.l10n.noWarehousesFoundSubtitle,
              )
            : ListView.separated(
                itemCount: names.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, i) {
                  final name = names[i];
                  return ListTile(
                    leading: const Icon(Icons.warehouse_outlined),
                    title: Text(name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      '/warehouse/${Uri.encodeComponent(name)}',
                    ),
                  );
                },
              ),
      ),
    );
  }
}
