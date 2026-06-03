import '../../domain/entities/item.dart';

class ItemModel {
  final String itemCode;
  final String itemName;
  final String? description;
  final String? stockUom;
  final String? image;
  final bool disabled;

  const ItemModel({
    required this.itemCode,
    required this.itemName,
    this.description,
    this.stockUom,
    this.image,
    this.disabled = false,
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      itemCode: json['item_code'] as String,
      itemName: (json['item_name'] as String?) ?? (json['item_code'] as String),
      description: json['description'] as String?,
      stockUom: json['stock_uom'] as String?,
      image: json['image'] as String?,
      disabled: (json['disabled'] ?? 0) == 1,
    );
  }

  Item toEntity() => Item(
        itemCode: itemCode,
        itemName: itemName,
        description: description,
        stockUom: stockUom,
        image: image,
        disabled: disabled,
      );
}
