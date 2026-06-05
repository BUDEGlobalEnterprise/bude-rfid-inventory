import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/providers.dart';
import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../data/warehouse_remote_data_source.dart';
import '../../domain/submit_transfer_usecase.dart';
import '../../domain/transfer_draft.dart';

final warehouseRemoteProvider = Provider<WarehouseRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return WarehouseRemoteDataSource(apiClient.dio);
});

/// One-shot fetch — the user picks once per transfer; refetch happens on
/// re-entering the screen via FutureProvider.autoDispose.
final warehousesProvider = FutureProvider.autoDispose<List<String>>((ref) {
  return ref.watch(warehouseRemoteProvider).list();
});

final submitTransferUseCaseProvider = Provider<SubmitTransferUseCase>((ref) {
  return SubmitTransferUseCase(ref.watch(syncQueueProvider));
});

final transferDraftProvider =
    StateNotifierProvider<TransferDraftNotifier, TransferDraft>((ref) {
  return TransferDraftNotifier();
});

class TransferDraftNotifier extends StateNotifier<TransferDraft> {
  TransferDraftNotifier() : super(const TransferDraft());

  void setSource(String? warehouse) =>
      state = state.copyWith(sourceWarehouse: warehouse);

  void setTarget(String? warehouse) =>
      state = state.copyWith(targetWarehouse: warehouse);

  void addLine(TransferLine line) {
    // If the same item is already in the list, bump its qty instead of
    // adding a duplicate row.
    final existingIndex = state.lines.indexWhere(
      (l) => l.itemCode == line.itemCode,
    );
    if (existingIndex == -1) {
      state = state.copyWith(lines: [...state.lines, line]);
      return;
    }
    final updated = [...state.lines];
    updated[existingIndex] =
        updated[existingIndex].copyWith(qty: updated[existingIndex].qty + line.qty);
    state = state.copyWith(lines: updated);
  }

  void updateQty(String itemCode, double qty) {
    state = state.copyWith(
      lines: state.lines
          .map((l) => l.itemCode == itemCode ? l.copyWith(qty: qty) : l)
          .toList(),
    );
  }

  void removeLine(String itemCode) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.itemCode != itemCode).toList(),
    );
  }

  void clear() {
    state = const TransferDraft();
  }
}
