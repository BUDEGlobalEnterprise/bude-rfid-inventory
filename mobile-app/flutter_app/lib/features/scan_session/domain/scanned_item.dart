import 'package:equatable/equatable.dart';

import '../../inventory/domain/entities/item.dart';

class ScannedItem extends Equatable {
  final String barcode;
  final Item item;
  final double qty;

  const ScannedItem({
    required this.barcode,
    required this.item,
    this.qty = 1.0,
  });

  ScannedItem copyWith({double? qty}) =>
      ScannedItem(barcode: barcode, item: item, qty: qty ?? this.qty);

  @override
  List<Object?> get props => [barcode, item, qty];
}
