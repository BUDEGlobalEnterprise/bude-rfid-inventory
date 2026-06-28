import '../../domain/entities/item.dart';

class ItemModel {
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

  const ItemModel({
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

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      itemCode: json['item_code'] as String,
      itemName: (json['item_name'] as String?) ?? (json['item_code'] as String),
      description: json['description'] as String?,
      stockUom: json['stock_uom'] as String?,
      image: json['image'] as String?,
      disabled: (json['disabled'] ?? 0) == 1,
      itemGroup: json['item_group'] as String?,
      hasBatchNo: _truthy(json['has_batch_no']),
      hasSerialNo: _truthy(json['has_serial_no']),
      createNewBatch: _truthy(json['create_new_batch']),
    );
  }

  Map<String, dynamic> toJson() => {
        'item_code': itemCode,
        'item_name': itemName,
        if (description != null) 'description': description,
        if (stockUom != null) 'stock_uom': stockUom,
        if (image != null) 'image': image,
        'disabled': disabled ? 1 : 0,
        if (itemGroup != null) 'item_group': itemGroup,
        'has_batch_no': hasBatchNo ? 1 : 0,
        'has_serial_no': hasSerialNo ? 1 : 0,
        'create_new_batch': createNewBatch ? 1 : 0,
      };

  Item toEntity() => Item(
        itemCode: itemCode,
        itemName: itemName,
        description: description,
        stockUom: stockUom,
        image: image,
        disabled: disabled,
        itemGroup: itemGroup,
        hasBatchNo: hasBatchNo,
        hasSerialNo: hasSerialNo,
        createNewBatch: createNewBatch,
      );
}

bool _truthy(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return {'1', 'true', 'yes', 'y'}
      .contains(value?.toString().trim().toLowerCase());
}
