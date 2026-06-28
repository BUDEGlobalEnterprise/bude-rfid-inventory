import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/providers.dart';
import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../../tracking/domain/tracking_allocation.dart';
import '../../data/purchase_order_remote_data_source.dart';
import '../../domain/receipt_draft.dart';
import '../../domain/submit_receipt_usecase.dart';

// Warehouses come from the same provider Transfer uses — no duplication.
export '../../../transfer/presentation/providers/transfer_providers.dart'
    show
        CompanySelectionRequiredException,
        operationCompanyProvider,
        warehouseLocationsProvider,
        warehousesProvider;

final purchaseOrderRemoteProvider =
    Provider<PurchaseOrderRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PurchaseOrderRemoteDataSource(apiClient.dio);
});

final purchaseOrdersProvider = FutureProvider.autoDispose<List<String>>((ref) {
  return ref.watch(purchaseOrderRemoteProvider).listOpen();
});

final submitReceiptUseCaseProvider = Provider<SubmitReceiptUseCase>((ref) {
  return SubmitReceiptUseCase(ref.watch(syncQueueProvider));
});

final receiptDraftProvider =
    StateNotifierProvider<ReceiptDraftNotifier, ReceiptDraft>((ref) {
  return ReceiptDraftNotifier();
});

class ReceiptDraftNotifier extends StateNotifier<ReceiptDraft> {
  ReceiptDraftNotifier() : super(const ReceiptDraft());

  void setTarget(String? warehouse) => state = state.copyWith(
        targetWarehouse: warehouse,
        targetLocation: null,
      );

  void setTargetLocation(String? location) =>
      state = state.copyWith(targetLocation: location);

  void setAgainstPo(String? po) {
    if (po == null || po.isEmpty) {
      state = state.copyWith(clearAgainstPo: true);
    } else {
      state = state.copyWith(againstPo: po);
    }
  }

  void addLine(ReceiptLine line) {
    final existingIndex =
        state.lines.indexWhere((l) => l.itemCode == line.itemCode);
    if (existingIndex == -1) {
      state = state.copyWith(lines: [...state.lines, line]);
      return;
    }
    final updated = [...state.lines];
    updated[existingIndex] = updated[existingIndex]
        .copyWith(qty: updated[existingIndex].qty + line.qty);
    state = state.copyWith(lines: updated);
  }

  void addLineIfAbsent(ReceiptLine line) {
    final exists = state.lines.any((l) => l.itemCode == line.itemCode);
    if (exists) return;
    state = state.copyWith(lines: [...state.lines, line]);
  }

  void updateQty(String itemCode, double qty) {
    state = state.copyWith(
      lines: state.lines
          .map((l) => l.itemCode == itemCode ? l.copyWith(qty: qty) : l)
          .toList(),
    );
  }

  void updateAllocations(
    String itemCode,
    List<TrackingAllocation> allocations,
  ) {
    state = state.copyWith(
      lines: state.lines
          .map(
            (l) => l.itemCode == itemCode
                ? l.copyWith(allocations: allocations)
                : l,
          )
          .toList(),
    );
  }

  void removeLine(String itemCode) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.itemCode != itemCode).toList(),
    );
  }

  void clear() {
    state = const ReceiptDraft();
  }
}
