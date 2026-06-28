import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/providers.dart';
import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../../transfer/presentation/providers/transfer_providers.dart'
    show operationCompanyProvider;
import '../../../tracking/domain/tracking_allocation.dart';
import '../../data/fulfillment_draft_local_data_source.dart';
import '../../data/sales_order_remote_data_source.dart';
import '../../domain/fulfillment_draft.dart';
import '../../domain/sales_order.dart';
import '../../domain/submit_sales_order_dispatch_usecase.dart';

final salesOrderRemoteProvider = Provider<SalesOrderRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SalesOrderRemoteDataSource(apiClient.dio);
});

final salesOrderListProvider =
    FutureProvider.autoDispose<List<SalesOrderSummary>>((ref) async {
  final company = await ref.watch(operationCompanyProvider.future);
  return ref.watch(salesOrderRemoteProvider).listOpen(company: company);
});

final salesOrderDetailProvider =
    FutureProvider.autoDispose.family<SalesOrderDetail, String>((ref, name) {
  return ref.watch(salesOrderRemoteProvider).get(name);
});

final fulfillmentDraftLocalProvider =
    Provider<FulfillmentDraftLocalDataSource>((ref) {
  return FulfillmentDraftLocalDataSource(
    ref.watch(fulfillmentDraftBoxProvider),
  );
});

final fulfillmentDraftProvider = StateNotifierProvider.autoDispose
    .family<FulfillmentDraftNotifier, FulfillmentDraft?, String>((ref, order) {
  return FulfillmentDraftNotifier(
    order,
    ref.watch(fulfillmentDraftLocalProvider),
  );
});

final submitSalesOrderDispatchUseCaseProvider =
    Provider<SubmitSalesOrderDispatchUseCase>((ref) {
  return SubmitSalesOrderDispatchUseCase(ref.watch(syncQueueProvider));
});

class FulfillmentDraftNotifier extends StateNotifier<FulfillmentDraft?> {
  final String salesOrder;
  final FulfillmentDraftLocalDataSource local;

  FulfillmentDraftNotifier(this.salesOrder, this.local)
      : super(local.get(salesOrder));

  Future<void> ensureSeeded(SalesOrderDetail order) async {
    if (state != null) return;
    state = FulfillmentDraft.fromSalesOrder(order);
    await _save();
  }

  Future<void> setSource(String? warehouse) async {
    final draft = state;
    if (draft == null) return;
    state = draft.setSource(warehouse);
    await _save();
  }

  Future<void> setSourceLocation(String? location) async {
    final draft = state;
    if (draft == null) return;
    state = draft.setSourceLocation(location);
    await _save();
  }

  Future<void> setStage(FulfillmentStage stage) async {
    final draft = state;
    if (draft == null) return;
    state = draft.copyWith(stage: stage);
    await _save();
  }

  Future<void> addPickedItem(String itemCode, double qty) async {
    final draft = state;
    if (draft == null) return;
    state = draft.addPickedItem(itemCode, qty);
    await _save();
  }

  Future<void> setPickedQty(String salesOrderItem, double qty) async {
    final draft = state;
    if (draft == null) return;
    state = draft.setPickedQty(salesOrderItem, qty);
    await _save();
  }

  Future<void> setPackedQty(String salesOrderItem, double qty) async {
    final draft = state;
    if (draft == null) return;
    state = draft.setPackedQty(salesOrderItem, qty);
    await _save();
  }

  Future<void> setAllocations(
    String salesOrderItem,
    List<TrackingAllocation> allocations,
  ) async {
    final draft = state;
    if (draft == null) return;
    state = draft.setAllocations(salesOrderItem, allocations);
    await _save();
  }

  Future<void> confirmPickedAsPacked() async {
    final draft = state;
    if (draft == null) return;
    state = draft.confirmPickedAsPacked().copyWith(
          stage: FulfillmentStage.dispatch,
        );
    await _save();
  }

  Future<void> clear() async {
    await local.delete(salesOrder);
    state = null;
  }

  Future<void> _save() async {
    final draft = state;
    if (draft != null) await local.save(draft);
  }
}
