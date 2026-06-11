import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../domain/entities/item.dart';
import '../domain/entities/item_stock.dart';
import 'providers/item_search_notifier.dart';

class ItemDetailScreen extends ConsumerWidget {
  final String itemCode;
  const ItemDetailScreen({super.key, required this.itemCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(_itemDetailProvider(itemCode));

    return Scaffold(
      appBar: AppBar(title: Text(itemCode)),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) => data.fold(
          (failure) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(failure.message, textAlign: TextAlign.center),
            ),
          ),
          (payload) => _DetailBody(
            item: payload.$1,
            stock: payload.$2,
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Item item;
  final List<ItemStock> stock;
  const _DetailBody({required this.item, required this.stock});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(item.itemName, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          item.itemCode,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        if (item.description != null && item.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(item.description!),
        ],
        const SizedBox(height: 24),
        Text(
          'Stock by warehouse',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (stock.isEmpty)
          const Text('No stock records.')
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < stock.length; i++) ...[
                  if (i > 0) const Divider(height: 0),
                  _StockRow(row: stock[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _StockRow extends StatelessWidget {
  final ItemStock row;
  const _StockRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final uom = row.stockUom ?? '';
    return ListTile(
      title: Text(row.warehouse),
      subtitle: Text(
        'Actual: ${_fmt(row.actualQty)} $uom · '
        'Reserved: ${_fmt(row.reservedQty)} · '
        'Projected: ${_fmt(row.projectedQty)}',
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

final _itemDetailProvider = FutureProvider.family
    .autoDispose<Either<Failure, (Item, List<ItemStock>)>, String>(
  (ref, itemCode) async {
    final itemRepo = ref.watch(itemRepositoryProvider);

    final searchResult = await itemRepo.search(itemCode, limit: 5);
    final itemEither = searchResult.fold<Either<Failure, Item>>(
      Left.new,
      (items) {
        final exact = items.firstWhere(
          (i) => i.itemCode == itemCode,
          orElse: () => items.isNotEmpty
              ? items.first
              : Item(itemCode: itemCode, itemName: itemCode),
        );
        return Right(exact);
      },
    );

    final itemOrFailure = itemEither.fold<Failure?>((f) => f, (_) => null);
    if (itemOrFailure != null) return Left(itemOrFailure);

    final item = itemEither.getOrElse(() => throw StateError('unreachable'));
    final stockResult = await itemRepo.getStock(itemCode);
    return stockResult.fold(
      Left.new,
      (stock) => Right((item, stock)),
    );
  },
);
