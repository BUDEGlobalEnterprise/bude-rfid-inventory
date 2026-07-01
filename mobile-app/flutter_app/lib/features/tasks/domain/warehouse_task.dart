import 'package:equatable/equatable.dart';

enum WarehouseTaskKind {
  receivePurchaseOrder,
  fulfillSalesOrder,
  assetMaintenance,
}

enum WarehouseTaskFilter {
  all,
  assignedToMe,
  receiving,
  fulfillment,
  assetMaintenance,
}

class WarehouseTask extends Equatable {
  final String id;
  final WarehouseTaskKind kind;
  final String title;
  final String subtitle;
  final String priority;
  final String? dueDate;
  final String? assignedTo;
  final String? company;
  final String sourceDoctype;
  final String sourceName;
  final String? todoName;
  final int itemCount;
  final double pendingQty;
  final String? assetName;

  const WarehouseTask({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.priority,
    this.dueDate,
    this.assignedTo,
    this.company,
    required this.sourceDoctype,
    required this.sourceName,
    this.todoName,
    this.itemCount = 0,
    this.pendingQty = 0,
    this.assetName,
  });

  bool get isAssigned => assignedTo != null && assignedTo!.trim().isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        kind,
        title,
        subtitle,
        priority,
        dueDate,
        assignedTo,
        company,
        sourceDoctype,
        sourceName,
        todoName,
        itemCount,
        pendingQty,
        assetName,
      ];
}

WarehouseTaskKind warehouseTaskKindFromWire(String value) {
  return WarehouseTaskKind.values.firstWhere(
    (kind) => kind.name == value,
    orElse: () => WarehouseTaskKind.receivePurchaseOrder,
  );
}
