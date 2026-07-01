import 'package:bude_inventory/features/inventory/domain/entities/item.dart';
import 'package:bude_inventory/features/scan_session/domain/scanned_item.dart';
import 'package:flutter_test/flutter_test.dart';

const _item = Item(itemCode: 'ITEM-A', itemName: 'Widget A', stockUom: 'Nos');

void main() {
  test('isUnresolved is true only when item is null', () {
    expect(
      const ScannedItem(barcode: 'B-1', item: null).isUnresolved,
      isTrue,
    );
    expect(
      const ScannedItem(barcode: 'B-1', item: _item).isUnresolved,
      isFalse,
    );
  });

  test('copyWith(qty:) leaves exception fields untouched', () {
    const original = ScannedItem(
      barcode: 'B-1',
      item: _item,
      exceptionType: ScanExceptionType.damage,
      exceptionNote: 'dented',
    );

    final updated = original.copyWith(qty: 5);

    expect(updated.qty, 5);
    expect(updated.exceptionType, ScanExceptionType.damage);
    expect(updated.exceptionNote, 'dented');
  });

  test('copyWith sets exception fields when passed explicitly', () {
    const original = ScannedItem(barcode: 'B-1', item: _item);

    final flagged = original.copyWith(
      exceptionType: ScanExceptionType.shortage,
      exceptionNote: 'only 2 of 5 arrived',
    );

    expect(flagged.exceptionType, ScanExceptionType.shortage);
    expect(flagged.exceptionNote, 'only 2 of 5 arrived');
  });

  test('copyWith clears exception fields when passed null explicitly', () {
    const flagged = ScannedItem(
      barcode: 'B-1',
      item: _item,
      exceptionType: ScanExceptionType.damage,
      exceptionNote: 'dented',
    );

    final cleared = flagged.copyWith(exceptionType: null, exceptionNote: null);

    expect(cleared.exceptionType, isNull);
    expect(cleared.exceptionNote, isNull);
  });

  test('equality includes exception fields', () {
    const a = ScannedItem(
      barcode: 'B-1',
      item: _item,
      exceptionType: ScanExceptionType.damage,
    );
    const b = ScannedItem(
      barcode: 'B-1',
      item: _item,
      exceptionType: ScanExceptionType.damage,
    );
    const c = ScannedItem(barcode: 'B-1', item: _item);

    expect(a, b);
    expect(a, isNot(c));
  });
}
