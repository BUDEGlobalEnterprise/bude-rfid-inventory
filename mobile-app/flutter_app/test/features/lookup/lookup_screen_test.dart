import 'dart:async';

import 'package:bude_inventory/core/errors/exceptions.dart';
import 'package:bude_inventory/core/hardware/adapters/rfid_adapter.dart';
import 'package:bude_inventory/core/hardware/entities/rfid_tag.dart';
import 'package:bude_inventory/core/hardware/entities/scan_event.dart';
import 'package:bude_inventory/core/hardware/providers.dart';
import 'package:bude_inventory/features/lookup/data/epc_remote_data_source.dart';
import 'package:bude_inventory/features/lookup/presentation/lookup_screen.dart';
import 'package:bude_inventory/features/lookup/presentation/providers/lookup_providers.dart';
import 'package:bude_inventory/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('shows inline error when RFID reader is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _LookupHost(
        dataSource: _FakeEpcDataSource(),
        rfid: null,
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Read RFID'));
    await tester.pump();

    expect(find.text('No RFID reader is available.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Scan'), findsOneWidget);
  });

  testWidgets('shows demo RFID banner and resolves a manual query', (
    tester,
  ) async {
    final dataSource = _FakeEpcDataSource()
      ..resolveResults.add(
        const ScanMatch(
          matchType: 'item',
          item: {'item_code': 'ITEM-001', 'item_name': 'Demo Widget'},
        ),
      );

    await tester.pumpWidget(
      _LookupHost(
        dataSource: dataSource,
        rfid: _FakeRfidAdapter(vendor: 'demo'),
      ),
    );
    await tester.pump();

    expect(
      find.text('Demo RFID reader active. Reads use sample EPC tags.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byType(TextField).first,
      'ITEM-001',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Resolve'));
    await tester.pumpAndSettle();

    expect(dataSource.resolvedQueries, ['ITEM-001']);
    expect(find.text('Demo Widget'), findsOneWidget);
    expect(find.text('ITEM-001'), findsWidgets);
  });

  testWidgets('barcode scan result is resolved and displayed', (tester) async {
    final dataSource = _FakeEpcDataSource()
      ..resolveResults.add(
        const ScanMatch(
          matchType: 'item',
          item: {'item_code': 'ITEM-BAR', 'item_name': 'Barcode Widget'},
        ),
      );

    await tester.pumpWidget(
      _LookupHost(
        dataSource: dataSource,
        rfid: null,
        scanBarcode: 'BAR-001',
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return barcode'));
    await tester.pumpAndSettle();

    expect(dataSource.resolvedQueries, ['BAR-001']);
    expect(find.text('Barcode Widget'), findsOneWidget);
    expect(find.text('ITEM-BAR'), findsWidgets);
  });

  testWidgets('RFID tag read is resolved and displayed', (tester) async {
    final dataSource = _FakeEpcDataSource()
      ..resolveResults.add(
        const ScanMatch(
          matchType: 'asset',
          asset: {
            'name': 'AST-001',
            'asset_name': 'RFID Forklift',
            'status': 'In Use',
          },
        ),
      );

    await tester.pumpWidget(
      _LookupHost(
        dataSource: dataSource,
        rfid: _FakeRfidAdapter(vendor: 'chainway'),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Read RFID'));
    await tester.pumpAndSettle();

    expect(dataSource.resolvedQueries, ['EPC-DEMO']);
    expect(find.text('RFID Forklift'), findsOneWidget);
    expect(find.text('AST-001'), findsOneWidget);
  });

  testWidgets('offline lookup shows localized error and retry keeps query', (
    tester,
  ) async {
    final dataSource = _FakeEpcDataSource()
      ..resolveResults.addAll([
        const NetworkException('socket failed'),
        const ScanMatch(
          matchType: 'item',
          item: {'item_code': 'ITEM-RETRY', 'item_name': 'Retry Widget'},
        ),
      ]);

    await tester.pumpWidget(
      _LookupHost(
        dataSource: dataSource,
        rfid: null,
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'EPC-OFFLINE');
    await tester.tap(find.widgetWithText(FilledButton, 'Resolve'));
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to connect. Check your network and try again.'),
      findsOneWidget,
    );
    expect(find.text('EPC-OFFLINE'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(dataSource.resolvedQueries, ['EPC-OFFLINE', 'EPC-OFFLINE']);
    expect(find.text('Retry Widget'), findsOneWidget);
  });
}

class _LookupHost extends StatelessWidget {
  final _FakeEpcDataSource dataSource;
  final RfidAdapter? rfid;
  final String? scanBarcode;

  const _LookupHost({
    required this.dataSource,
    required this.rfid,
    this.scanBarcode,
  });

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/lookup',
      routes: [
        GoRoute(
          path: '/lookup',
          builder: (context, state) => const LookupScreen(),
        ),
        GoRoute(
          path: '/scan',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.pop(
                  ScanEvent(barcode: scanBarcode ?? 'BAR-001'),
                ),
                child: const Text('Return barcode'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/items/:itemCode',
          builder: (context, state) => const Scaffold(body: Text('Item')),
        ),
        GoRoute(
          path: '/assets/:assetId',
          builder: (context, state) => const Scaffold(body: Text('Asset')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        epcDataSourceProvider.overrideWithValue(dataSource),
        rfidAdapterProvider.overrideWithValue(rfid),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}

class _FakeEpcDataSource extends EpcRemoteDataSource {
  final List<Object> resolveResults = [];
  final List<String> resolvedQueries = [];

  _FakeEpcDataSource() : super(Dio());

  @override
  Future<ScanMatch> resolve(String epc) async {
    resolvedQueries.add(epc);
    final result = resolveResults.removeAt(0);
    if (result is Exception) throw result;
    return result as ScanMatch;
  }
}

class _FakeRfidAdapter implements RfidAdapter {
  @override
  final String vendor;

  _FakeRfidAdapter({required this.vendor});

  @override
  bool get isConnected => true;

  @override
  Stream<RfidTag> get tagStream => const Stream.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<int> getPowerLevel() async => 20;

  @override
  Future<void> killTag({required String killPassword}) async {}

  @override
  Future<void> lockTag({
    required RfidMemoryBank bank,
    required String accessPassword,
  }) async {}

  @override
  Future<RfidTag?> readTag({Duration timeout = const Duration(seconds: 5)}) {
    return Future.value(RfidTag(epc: 'EPC-DEMO'));
  }

  @override
  Future<void> setPowerLevel(int dbm) async {}

  @override
  Future<void> startInventory() async {}

  @override
  Future<void> stopInventory() async {}

  @override
  Future<void> writeTagEpc(String newEpc, {String? accessPassword}) async {}
}
