import 'package:equatable/equatable.dart';

class Item extends Equatable {
  final String itemCode;
  final String itemName;
  final String? description;
  final String? stockUom;
  final String? image;
  final bool disabled;

  const Item({
    required this.itemCode,
    required this.itemName,
    this.description,
    this.stockUom,
    this.image,
    this.disabled = false,
  });

  @override
  List<Object?> get props => [
        itemCode,
        itemName,
        description,
        stockUom,
        image,
        disabled,
      ];
}
