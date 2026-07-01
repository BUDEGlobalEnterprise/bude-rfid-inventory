import '../../inventory/domain/entities/item.dart';

class ReceiptRouteExtra {
  final Item? initialItem;
  final String? againstPo;
  final String? todoName;

  const ReceiptRouteExtra({
    this.initialItem,
    this.againstPo,
    this.todoName,
  });
}
