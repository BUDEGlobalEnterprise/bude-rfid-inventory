import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failures.dart';
import '../../../core/ui/empty_state_view.dart';
import '../../../core/ui/loading_shimmer.dart';
import '../../../core/ui/operational_components.dart';
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

class _StockTab extends StatelessWidget {
  final Item item;
  final List<ItemStock> stock;
  const _StockTab({required this.item, required this.stock});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final actual = stock.fold<double>(0, (sum, row) => sum + row.actualQty);
    final reserved = stock.fold<double>(0, (sum, row) => sum + row.reservedQty);
    final projected =
        stock.fold<double>(0, (sum, row) => sum + row.projectedQty);
    final ordered = stock.fold<double>(0, (sum, row) => sum + row.orderedQty);
    final available = actual - reserved;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BudeOperationHeader(
          icon: Icons.inventory_2_outlined,
          title: item.itemName,
          subtitle: item.itemCode,
          pills: [
            BudeSummaryPill(
              icon: Icons.inventory,
              label: context.l10n.actualQty,
              value: _fmt(actual),
            ),
            BudeSummaryPill(
              icon: Icons.lock_clock,
              label: context.l10n.reservedQty,
              value: _fmt(reserved),
            ),
            BudeSummaryPill(
              icon: Icons.trending_up,
              label: context.l10n.projectedQty,
              value: _fmt(projected),
            ),
            BudeSummaryPill(
              icon: Icons.done_all,
              label: 'Available',
              value: _fmt(available),
            ),
            BudeSummaryPill(
              icon: Icons.local_shipping_outlined,
              label: 'Ordered',
              value: _fmt(ordered),
            ),
            if (item.itemGroup != null && item.itemGroup!.isNotEmpty)
              BudeStatusChip(
                label: item.itemGroup!,
                icon: Icons.category_outlined,
                color: scheme.primary,
              ),
            if (item.stockUom != null && item.stockUom!.isNotEmpty)
              BudeStatusChip(
                label: item.stockUom!,
                icon: Icons.straighten,
                color: scheme.tertiary,
              ),
            BudeStatusChip(
              label: item.disabled ? context.l10n.disabledStatus : 'Active',
              icon: item.disabled ? Icons.block : Icons.check_circle_outline,
              color: item.disabled ? scheme.error : scheme.secondary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ItemIdentityPanel(item: item),
        if (item.description != null && item.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            item.description!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
        const SizedBox(height: 16),
        _StockInsightPanel(stock: stock),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.swap_horiz),
              label: Text(context.l10n.transfer),
              onPressed: () => context.push('/transfer', extra: item),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.input),
              label: Text(context.l10n.receive),
              onPressed: () => context.push('/receipt', extra: item),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.fact_check),
              label: Text(context.l10n.count),
              onPressed: () => context.push('/reconcile', extra: item),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Stock by warehouse',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (stock.isEmpty)
          const EmptyStateView(
            icon: Icons.warehouse_outlined,
            title: 'No stock records',
            subtitle: 'Warehouse quantities will appear once stock exists.',
          )
        else
          for (final row in stock) _StockRow(row: row),
      ],
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

class _ItemIdentityPanel extends StatelessWidget {
  final Item item;
  const _ItemIdentityPanel({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ItemVisual(item: item),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _DetailFact(label: 'Code', value: item.itemCode),
                  _DetailFact(label: 'Name', value: item.itemName),
                  _DetailFact(
                    label: 'Group',
                    value: _orDash(item.itemGroup),
                  ),
                  _DetailFact(label: 'UOM', value: _orDash(item.stockUom)),
                  _DetailFact(
                    label: 'Status',
                    value: item.disabled ? 'Disabled' : 'Active',
                  ),
                  if (item.image != null && item.image!.isNotEmpty)
                    _DetailFact(label: 'Image', value: item.image!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _orDash(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? '-' : text;
  }
}

class _ItemVisual extends StatelessWidget {
  final Item item;
  const _ItemVisual({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = item.image;
    final canLoadImage = image != null &&
        (image.startsWith('http://') || image.startsWith('https://'));

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 72,
        height: 72,
        color: scheme.primaryContainer.withValues(alpha: 0.65),
        child: canLoadImage
            ? Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _FallbackIcon(scheme: scheme),
              )
            : _FallbackIcon(scheme: scheme),
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  final ColorScheme scheme;
  const _FallbackIcon({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.inventory_2_outlined,
      color: scheme.onPrimaryContainer,
      size: 32,
    );
  }
}

class _DetailFact extends StatelessWidget {
  final String label;
  final String value;

  const _DetailFact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _StockInsightPanel extends StatelessWidget {
  final List<ItemStock> stock;
  const _StockInsightPanel({required this.stock});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final actual = stock.fold<double>(0, (sum, row) => sum + row.actualQty);
    final reserved = stock.fold<double>(0, (sum, row) => sum + row.reservedQty);
    final ordered = stock.fold<double>(0, (sum, row) => sum + row.orderedQty);
    final available = actual - reserved;
    final stockedWarehouses = stock.where((row) => row.actualQty != 0).length;
    final negativeWarehouses = stock.where((row) => row.actualQty < 0).length;
    final topRow = stock.isEmpty
        ? null
        : stock.reduce(
            (a, b) => a.actualQty >= b.actualQty ? a : b,
          );

    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Stock insight',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricTile(
                  label: 'Available',
                  value: _fmt(available),
                  icon: Icons.done_all,
                  color: available < 0 ? scheme.error : scheme.secondary,
                ),
                _MetricTile(
                  label: 'Ordered',
                  value: _fmt(ordered),
                  icon: Icons.local_shipping_outlined,
                  color: scheme.tertiary,
                ),
                _MetricTile(
                  label: 'Warehouses',
                  value: '$stockedWarehouses/${stock.length}',
                  icon: Icons.warehouse_outlined,
                  color: scheme.primary,
                ),
                _MetricTile(
                  label: 'Negative bins',
                  value: '$negativeWarehouses',
                  icon: Icons.warning_amber_outlined,
                  color: negativeWarehouses > 0 ? scheme.error : scheme.outline,
                ),
              ],
            ),
            if (topRow != null) ...[
              const SizedBox(height: 12),
              Text(
                'Highest stock: ${topRow.warehouse} (${_fmt(topRow.actualQty)} ${topRow.stockUom ?? ''})'
                    .trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 146,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  final ItemStock row;
  const _StockRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uom = row.stockUom ?? '';
    final actualColor = row.actualQty > 0 ? scheme.secondary : scheme.outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.warehouse_outlined, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.warehouse,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        BudeStatusChip(
                          label: 'Actual ${_fmt(row.actualQty)} $uom'.trim(),
                          icon: Icons.inventory,
                          color: actualColor,
                        ),
                        BudeStatusChip(
                          label: 'Reserved ${_fmt(row.reservedQty)}',
                          icon: Icons.lock_clock,
                          color: scheme.tertiary,
                        ),
                        BudeStatusChip(
                          label: 'Projected ${_fmt(row.projectedQty)}',
                          icon: Icons.trending_up,
                          color: scheme.primary,
                        ),
                        if (row.orderedQty != 0)
                          BudeStatusChip(
                            label: 'Ordered ${_fmt(row.orderedQty)}',
                            icon: Icons.local_shipping_outlined,
                            color: scheme.secondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

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
    final valueDiff = entry.stockValueDifference;
    final valueDiffText = valueDiff == null
        ? null
        : valueDiff >= 0
            ? '+${_fmt(valueDiff)}'
            : _fmt(valueDiff);

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
          if (entry.voucherNo.isNotEmpty)
            Text(
              entry.voucherNo,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          Text(
            entry.warehouse,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          Text(
            l10n.balanceAfter(balanceStr),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          if (entry.valuationRate != null || valueDiffText != null)
            Text(
              [
                if (entry.valuationRate != null)
                  'Rate ${_fmt(entry.valuationRate!)}',
                if (valueDiffText != null) 'Value $valueDiffText',
              ].join(' - '),
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
