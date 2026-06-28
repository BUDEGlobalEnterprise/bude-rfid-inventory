import 'package:equatable/equatable.dart';

class Item extends Equatable {
  final String itemCode;
  final String itemName;
  final String? description;
  final String? stockUom;
  final String? image;
  final bool disabled;
  final String? itemGroup;
  final bool hasBatchNo;
  final bool hasSerialNo;
  final bool createNewBatch;

  const Item({
    required this.itemCode,
    required this.itemName,
    this.description,
    this.stockUom,
    this.image,
    this.disabled = false,
    this.itemGroup,
    this.hasBatchNo = false,
    this.hasSerialNo = false,
    this.createNewBatch = false,
  });

  bool get requiresTracking => hasBatchNo || hasSerialNo;

  @override
  List<Object?> get props => [
        itemCode,
        itemName,
        description,
        stockUom,
        image,
        disabled,
        itemGroup,
        hasBatchNo,
        hasSerialNo,
        createNewBatch,
      ];
}
