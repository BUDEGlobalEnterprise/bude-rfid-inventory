import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/providers.dart';
import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../../company/presentation/providers/company_providers.dart';
import '../../../settings/presentation/providers/settings_notifier.dart';
import '../../../tracking/domain/tracking_allocation.dart';
import '../../data/warehouse_remote_data_source.dart';
import '../../domain/submit_transfer_usecase.dart';
import '../../domain/transfer_draft.dart';

final warehouseRemoteProvider = Provider<WarehouseRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return WarehouseRemoteDataSource(apiClient.dio);
});

class CompanySelectionRequiredException implements Exception {
  const CompanySelectionRequiredException();

  @override
  String toString() => 'Select a company before choosing warehouses.';
}

final operationCompanyProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  final activeCompany = ref.watch(
    settingsNotifierProvider.select((settings) => settings.activeCompany),
  );
  if (activeCompany != null && activeCompany.trim().isNotEmpty) {
    return activeCompany.trim();
  }

  final companies = await ref.watch(companiesProvider.future);
  if (companies.length == 1) return companies.single.name;
  if (companies.length > 1) throw const CompanySelectionRequiredException();
  return null;
});

final warehousesProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final company = await ref.watch(operationCompanyProvider.future);
  return ref.watch(warehouseRemoteProvider).list(company: company);
});

final warehouseLocationsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, warehouse) async {
  final company = await ref.watch(operationCompanyProvider.future);
  return ref
      .watch(warehouseRemoteProvider)
      .listLocations(warehouse, company: company);
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

  void setSource(String? warehouse) => state = state.copyWith(
        sourceWarehouse: warehouse,
        sourceLocation: null,
      );

  void setSourceLocation(String? location) =>
      state = state.copyWith(sourceLocation: location);

  void setTarget(String? warehouse) => state = state.copyWith(
        targetWarehouse: warehouse,
        targetLocation: null,
      );

  void setTargetLocation(String? location) =>
      state = state.copyWith(targetLocation: location);

  void addLine(TransferLine line) {
    final existingIndex = state.lines.indexWhere(
      (l) => l.itemCode == line.itemCode,
    );
    if (existingIndex == -1) {
      state = state.copyWith(lines: [...state.lines, line]);
      return;
    }
    final updated = [...state.lines];
    updated[existingIndex] = updated[existingIndex]
        .copyWith(qty: updated[existingIndex].qty + line.qty);
    state = state.copyWith(lines: updated);
  }

  void addLineIfAbsent(TransferLine line) {
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
    state = const TransferDraft();
  }
}
