import 'package:bude_inventory/features/labels/data/label_generator.dart';
import 'package:bude_inventory/features/labels/domain/label_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PDF generator returns a PDF document for a label request', () async {
    const request = LabelRequest(
      kind: LabelKind.item,
      title: 'Widget',
      primaryCode: 'ITEM-001',
    );

    final bytes = await LabelGenerator.buildPdf(request);

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('ZPL generator emits Code128 labels once per quantity count', () {
    const request = LabelRequest(
      kind: LabelKind.item,
      format: LabelFormat.zpl,
      size: LabelSize.medium75x50,
      title: 'Widget',
      primaryCode: 'ITEM-001',
      quantity: 2,
      metadata: {'UOM': 'Nos'},
    );

    final zpl = LabelGenerator.buildZpl(request);

    expect(RegExp(r'\^XA').allMatches(zpl), hasLength(2));
    expect(RegExp(r'\^XZ').allMatches(zpl), hasLength(2));
    expect(zpl, contains('^PW600'));
    expect(zpl, contains('^LL400'));
    expect(zpl, contains('^BCN'));
    expect(zpl, contains('^FDITEM-001^FS'));
    expect(zpl, contains('^FDUOM: Nos^FS'));
  });

  test('ZPL generator emits QR command for receipt labels', () {
    const request = LabelRequest(
      kind: LabelKind.receipt,
      format: LabelFormat.zpl,
      title: 'Goods receipt',
      primaryCode: 'op-123',
      receiptOpId: 'op-123',
      receiptPayload: {'target_warehouse': 'Receiving - A'},
    );

    final zpl = LabelGenerator.buildZpl(request);

    expect(zpl, contains('^BQN'));
    expect(zpl, isNot(contains('^BCN')));
    expect(zpl, contains('^FDLA,'));
    expect(zpl, contains('"op_id":"op-123"'));
  });

  test('ZPL text strips control command characters from user text', () {
    const request = LabelRequest(
      kind: LabelKind.binLocation,
      format: LabelFormat.zpl,
      title: 'Dock ^A',
      primaryCode: 'BIN~01',
    );

    final zpl = LabelGenerator.buildZpl(request);

    expect(zpl, contains('^FDDock  A^FS'));
    expect(zpl, contains('^FDBIN 01^FS'));
  });
}
