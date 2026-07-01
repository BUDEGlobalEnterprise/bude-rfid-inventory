import 'dart:async';

import 'package:bude_inventory/core/errors/failures.dart';
import 'package:bude_inventory/core/hardware/adapters/barcode_adapter.dart';
import 'package:bude_inventory/core/hardware/entities/scan_event.dart';
import 'package:bude_inventory/core/hardware/providers.dart';
import 'package:bude_inventory/features/inventory/domain/entities/item.dart';
import 'package:bude_inventory/features/inventory/domain/repositories/item_repository.dart';
import 'package:bude_inventory/features/inventory/domain/usecases/get_item_by_barcode_usecase.dart';
import 'package:bude_inventory/features/inventory/presentation/providers/item_search_notifier.dart';
import 'package:bude_inventory/features/scan_session/domain/scan_session_mode.dart';
import 'package:bude_inventory/features/scan_session/domain/scanned_item.dart';
import 'package:bude_inventory/features/scan_session/presentation/scan_session_screen.dart';
import 'package:bude_inventory/l10n/app_localizations.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

const _itemA = Item(itemCode: 'ITEM-A', itemName: 'Widget A', stockUom: 'Nos');

class _FakeBarcodeAdapter implements BarcodeAdapter {
  final _controller = StreamController<ScanEvent>.broadcast();

  @override
  String get vendor => 'fake';

  @override
  Stream<ScanEvent> get events => _controller.stream;

  @override
  Future<void> startScan() async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<ScanEvent?> scanSingle({
    Duration timeout = const Duration(seconds: 30),
  }) async =>
      null;

  @override
  bool get supportsContinuousScan => true;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  void emit(String barcode) => _controller.add(ScanEvent(barcode: barcode));
}

class _MockItemRepository extends Mock implements ItemRepository {}

class _FakeGetItemByBarcodeUseCase extends GetItemByBarcodeUseCase {
  final Map<String, Item> resolvable;
  _FakeGetItemByBarcodeUseCase(this.resolvable) : super(_MockItemRepository());

  @override
  Future<Either<Failure, Item>> call(String params) async {
    final item = resolvable[params];
    if (item == null) return const Left(ServerFailure('not found'));
    return Right(item);
  }
}

void main() {
  late _FakeBarcodeAdapter adapter;
  List<ScannedItem>? poppedResult;

  Future<void> pumpScreen(WidgetTester tester) async {
    adapter = _FakeBarcodeAdapter();
    poppedResult = null;
    await tester.pumpWidget(
      _Host(
        adapter: adapter,
        onResult: (r) => poppedResult = r,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('an unresolved scan is shown, not discarded, and can be removed', (
    tester,
  ) async {
    await pumpScreen(tester);

    adapter.emit('UNKNOWN-1');
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Unresolved scan'), findsOneWidget);
    expect(find.text('UNKNOWN-1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pump();

    expect(find.text('Unresolved scan'), findsNothing);
  });

  testWidgets(
    'a resolved scan can be flagged as damage with a note, and it carries '
    'through to the popped result',
    (tester) async {
      await pumpScreen(tester);

      adapter.emit('BARCODE-A');
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Widget A'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.report_problem_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Damage'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Note (optional)'),
        'dented on arrival',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Damage'), findsOneWidget); // chip on the tile now

      await tester.tap(find.widgetWithText(FilledButton, 'Use 1 items'));
      await tester.pumpAndSettle();

      expect(poppedResult, hasLength(1));
      expect(poppedResult!.single.exceptionType, ScanExceptionType.damage);
      expect(poppedResult!.single.exceptionNote, 'dented on arrival');
    },
  );
}

class _Host extends StatelessWidget {
  final _FakeBarcodeAdapter adapter;
  final ValueChanged<List<ScannedItem>?> onResult;

  const _Host({required this.adapter, required this.onResult});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/base',
      routes: [
        GoRoute(
          path: '/base',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final result = await context
                      .push<List<ScannedItem>>('/scan-session');
                  onResult(result);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/scan-session',
          builder: (context, state) =>
              const ScanSessionScreen(mode: ScanSessionMode.transfer),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        barcodeAdapterProvider.overrideWithValue(adapter),
        getItemByBarcodeUseCaseProvider.overrideWithValue(
          _FakeGetItemByBarcodeUseCase({'BARCODE-A': _itemA}),
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}
