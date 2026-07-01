import 'package:bude_inventory/features/inventory/domain/entities/item.dart';
import 'package:bude_inventory/features/labels/domain/label_request.dart';
import 'package:bude_inventory/features/labels/domain/label_request_builders.dart';
import 'package:bude_inventory/features/labels/presentation/label_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders each label type form', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LabelScreen()));

    expect(find.text('Label printing'), findsOneWidget);
    expect(find.text('Pallet ID *'), findsOneWidget);

    await tester.tap(find.text('Item'));
    await tester.pumpAndSettle();
    expect(find.text('Item code *'), findsOneWidget);
    expect(find.text('Item name *'), findsOneWidget);

    await tester.tap(find.text('Bin'));
    await tester.pumpAndSettle();
    expect(find.text('Location name *'), findsOneWidget);
    expect(find.text('Parent warehouse'), findsOneWidget);

    await tester.tap(find.text('Receipt'));
    await tester.pumpAndSettle();
    expect(find.text('Receipt op/server ref *'), findsOneWidget);
    expect(find.text('Target warehouse'), findsOneWidget);
    expect(find.text('Purchase order'), findsOneWidget);
  });

  testWidgets('initial item request pre-fills item label fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LabelScreen(
          initialRequest: itemLabelRequest(
            const Item(
              itemCode: 'ITEM-001',
              itemName: 'Widget',
              stockUom: 'Nos',
              itemGroup: 'Finished Goods',
            ),
          ),
        ),
      ),
    );

    expect(find.text('ITEM-001'), findsWidgets);
    expect(find.text('Widget'), findsWidgets);
    expect(find.text('UOM: Nos'), findsOneWidget);
    expect(find.text('Group: Finished Goods'), findsOneWidget);
  });

  testWidgets('validation blocks empty pallet ID and zero quantity', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LabelScreen()));

    await tester.enterText(
      find.byKey(const ValueKey('label-primary-code-field')),
      '',
    );
    await tester.tap(find.text('Share PDF'));
    await tester.pump();
    expect(find.text('Enter a pallet code before printing.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('label-primary-code-field')),
      'PAL-001',
    );
    await tester.tap(find.byTooltip('Decrease quantity'));
    await tester.pump();
    await tester.tap(find.text('Share PDF'));
    await tester.pump();
    expect(find.text('Quantity must be at least 1.'), findsOneWidget);
  });
}
