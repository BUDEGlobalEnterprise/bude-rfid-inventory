import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failures.dart';
import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/loading_shimmer.dart';
import '../../../core/utils/locale_ext.dart';
import '../domain/entities/item.dart';
import '../domain/entities/item_stock.dart';
import '../domain/entities/stock_ledger_entry.dart';
import 'providers/item_search_notifier.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  final String itemCode;
  const ItemDetailScreen({super.key, required this.itemCode});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(_itemDetailProvider(widget.itemCode));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.itemCode),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: context.l10n.stockTab),
            Tab(text: context.l10n.historyTab),
          ],
        ),
      ),
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
          (payload) => TabBarView(
            controller: _tabs,
            children: [
              _StockTab(item: payload.$1, stock: payload.$2),
              _HistoryTab(itemCode: widget.itemCode),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stock tab ─────────────────────────────────────────────────────────────────

class _StockTab extends StatelessWidget {
  final Item item;
  final List<ItemStock> stock;
  const _StockTab({required this.item, required this.stock});

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

// ── History tab ───────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  final String itemCode;
  const _HistoryTab({required this.itemCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(_ledgerProvider(itemCode));

    return ledgerAsync.when(
      loading: () => const ShimmerList(count: 8),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (data) => data.fold(
        (failure) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(failure.message, textAlign: TextAlign.center),
          ),
        ),
        (entries) => entries.isEmpty
            ? EmptyStateView(
                icon: Icons.history,
                title: context.l10n.noMovementHistory,
                subtitle: context.l10n.noMovementHistorySubtitle,
              )
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(_ledgerProvider(itemCode)),
                child: _LedgerList(entries: entries),
              ),
      ),
    );
  }
}

class _LedgerList extends StatelessWidget {
  final List<StockLedgerEntry> entries;
  const _LedgerList({required this.entries});

  static final _dateFmt = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = <Widget>[];
    String? lastDate;

    for (final entry in entries) {
      final dateStr = _dateFmt.format(entry.postingDate);
      if (dateStr != lastDate) {
        lastDate = dateStr;
        items.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              dateStr,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        );
      }
      items.add(_LedgerTile(entry: entry));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: items,
    );
  }
}

class _LedgerTile extends StatelessWidget {
  final StockLedgerEntry entry;
  const _LedgerTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final qty = entry.actualQty;
    final positive = qty >= 0;
    final qtyColor = positive ? Colors.green.shade700 : Colors.red.shade700;
    final qtyStr = positive ? '+${_fmt(qty)}' : _fmt(qty);
    final balanceStr = _fmt(entry.qtyAfterTransaction);

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: positive
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.12),
        child: Icon(
          positive ? Icons.arrow_upward : Icons.arrow_downward,
          size: 18,
          color: qtyColor,
        ),
      ),
      title: Text(entry.voucherType),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.warehouse,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          Text(
            l10n.balanceAfter(balanceStr),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
      trailing: Text(
        qtyStr,
        style: TextStyle(
          color: qtyColor,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      isThreeLine: true,
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

// ── Providers ─────────────────────────────────────────────────────────────────

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

final _ledgerProvider = FutureProvider.family
    .autoDispose<Either<Failure, List<StockLedgerEntry>>, String>(
  (ref, itemCode) async {
    final repo = ref.watch(itemRepositoryProvider);
    return repo.getLedger(itemCode);
  },
);
