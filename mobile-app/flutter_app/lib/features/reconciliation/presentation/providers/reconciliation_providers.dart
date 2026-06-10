import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/providers.dart';
import '../../../inventory/presentation/providers/item_search_notifier.dart';
import '../../domain/reconciliation_draft.dart';
import '../../domain/submit_reconciliation_usecase.dart';

// Reuse the existing warehouse list provider from the transfer feature.
export '../../../transfer/presentation/providers/transfer_providers.dart'
    show warehousesProvider;

final submitReconciliationUseCaseProvider =
    Provider<SubmitReconciliationUseCase>((ref) {
  return SubmitReconciliationUseCase(ref.watch(syncQueueProvider));
});

final reconciliationDraftProvider =
    StateNotifierProvider<ReconciliationDraftNotifier, ReconciliationDraft>(
  (ref) => ReconciliationDraftNotifier(),
);

class ReconciliationDraftNotifier extends StateNotifier<ReconciliationDraft> {
  ReconciliationDraftNotifier() : super(const ReconciliationDraft());

  void setWarehouse(String? warehouse) {
    // Changing the warehouse invalidates all expected qtys — clear the lines.
    state = ReconciliationDraft(warehouse: warehouse);
  }

  void addLine(CountLine line) {
    final existingIndex =
        state.lines.indexWhere((l) => l.itemCode == line.itemCode);
    if (existingIndex == -1) {
      state = state.copyWith(lines: [...state.lines, line]);
      return;
    }
    // Same item scanned twice — bump the counted qty by 1 (rapid-counting UX).
    final updated = [...state.lines];
    final existing = updated[existingIndex];
    updated[existingIndex] = existing.copyWith(
      countedQty: existing.countedQty + line.countedQty,
    );
    state = state.copyWith(lines: updated);
  }

  void setCount(String itemCode, double qty) {
    state = state.copyWith(
      lines: state.lines
          .map((l) => l.itemCode == itemCode ? l.copyWith(countedQty: qty) : l)
          .toList(),
    );
  }

  void removeLine(String itemCode) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.itemCode != itemCode).toList(),
    );
  }

  void clear() {
    state = const ReconciliationDraft();
  }
}

/// Pre-fetches Bin (per-warehouse stock) for a given item so the
/// reconciliation screen can show ERPNext's expected qty next to the
/// operator's counted qty. Returns null on any failure (best-effort).
final expectedQtyProvider =
    FutureProvider.autoDispose.family<double?, _BinKey>((ref, key) async {
  if (key.warehouse == null) return null;
  final repo = ref.watch(itemRepositoryProvider);
  final result = await repo.getStock(key.itemCode, warehouse: key.warehouse);
  return result.fold(
    (_) => null,
    (rows) => rows.isEmpty ? null : rows.first.actualQty,
  );
});

class _BinKey {
  final String itemCode;
  final String? warehouse;
  const _BinKey(this.itemCode, this.warehouse);

  @override
  bool operator ==(Object other) =>
      other is _BinKey &&
      other.itemCode == itemCode &&
      other.warehouse == warehouse;

  @override
  int get hashCode => Object.hash(itemCode, warehouse);
}

// Re-export the BinKey so the screen can use it without seeing the class name.
typedef BinKey = _BinKey;
