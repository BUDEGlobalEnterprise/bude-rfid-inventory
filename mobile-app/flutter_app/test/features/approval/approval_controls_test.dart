import 'dart:async';

import 'package:bude_inventory/core/errors/failures.dart';
import 'package:bude_inventory/core/network/network_info_impl.dart';
import 'package:bude_inventory/core/sync/pending_operation.dart';
import 'package:bude_inventory/core/sync/providers.dart';
import 'package:bude_inventory/core/sync/sync_queue.dart';
import 'package:bude_inventory/features/authentication/domain/auth_repository.dart';
import 'package:bude_inventory/features/authentication/domain/auth_session.dart';
import 'package:bude_inventory/features/authentication/presentation/providers/auth_notifier.dart';
import 'package:bude_inventory/features/settings/domain/app_settings.dart';
import 'package:bude_inventory/features/settings/domain/settings_repository.dart';
import 'package:bude_inventory/features/settings/presentation/providers/settings_notifier.dart';
import 'package:bude_inventory/features/transfer/data/transfer_op_submitter.dart';
import 'package:bude_inventory/features/transfer/domain/transfer_draft.dart';
import 'package:bude_inventory/features/transfer/presentation/providers/transfer_providers.dart'
    as transfer;
import 'package:bude_inventory/features/transfer/presentation/transfer_screen.dart';
import 'package:bude_inventory/features/reconciliation/presentation/reconciliation_approval_screen.dart';
import 'package:bude_inventory/l10n/app_localizations.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_box.dart';

void main() {
  testWidgets(
    'high-quantity transfer queues pending approval and approval records audit metadata',
    (tester) async {
      final queue = SyncQueue(box: FakeBox());
      final notifier = transfer.TransferDraftNotifier()
        ..setSource('Stores - A')
        ..setTarget('Floor - A')
        ..addLine(
          const TransferLine(
            itemCode: 'ITEM-A',
            itemName: 'Widget A',
            qty: 12,
          ),
        );

      await tester.pumpWidget(
        _TransferApprovalHost(
          queue: queue,
          notifier: notifier,
          settings: const AppSettings(
            activeCompany: 'Bude Global',
            transferApprovalQtyThreshold: 10,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Queue transfer'));
      await tester.pumpAndSettle();

      final queued = queue.all().single;
      expect(queued.type, kStockTransferOpType);
      expect(queued.status, OpStatus.pendingApproval);
      expect(queued.payload['approval_metric'], 'transfer_qty');
      expect(queued.payload['approval_threshold'], 10.0);
      expect(
        queued.payload['approval_reason'],
        'Transfer quantity 12 exceeds threshold 10.',
      );
      expect(find.text('Stock transfer'), findsWidgets);
      expect(
        find.text('Transfer quantity 12 exceeds threshold 10.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).at(0), 'manager@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'secret');
      await tester.tap(find.widgetWithText(FilledButton, 'Approve as Supervisor'));
      await tester.pumpAndSettle();

      final approved = queue.getById(queued.id)!;
      expect(approved.status, OpStatus.pending);
      expect(approved.payload['approved_by'], 'manager@example.com');
      expect(approved.payload['approved_at'], isA<String>());

      await queue.dispose();
    },
  );
}

class _TransferApprovalHost extends StatelessWidget {
  final SyncQueue queue;
  final transfer.TransferDraftNotifier notifier;
  final AppSettings settings;

  const _TransferApprovalHost({
    required this.queue,
    required this.notifier,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final network = _MockNetworkInfo();
    when(() => network.isConnected).thenAnswer((_) async => false);
    when(() => network.onConnectivityChanged())
        .thenAnswer((_) => const Stream<bool>.empty());

    final router = GoRouter(
      initialLocation: '/transfer',
      routes: [
        GoRoute(
          path: '/transfer',
          builder: (context, state) => const TransferScreen(),
        ),
        GoRoute(
          path: '/reconcile/approve',
          builder: (context, state) => ReconciliationApprovalScreen(
            opId: state.extra! as String,
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        syncQueueProvider.overrideWithValue(queue),
        networkInfoProvider.overrideWithValue(network),
        transfer.transferDraftProvider.overrideWith((ref) => notifier),
        transfer.warehousesProvider.overrideWith(
          (ref) async => ['Stores - A', 'Floor - A'],
        ),
        transfer.warehouseLocationsProvider.overrideWith(
          (ref, warehouse) async => const <String>[],
        ),
        settingsNotifierProvider.overrideWith(
          (ref) => _SettingsNotifierForTest(settings),
        ),
        authRepositoryProvider.overrideWithValue(
          const _ApprovingAuthRepository(),
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

class _MockNetworkInfo extends Mock implements NetworkInfoImpl {}

class _ApprovingAuthRepository implements AuthRepository {
  const _ApprovingAuthRepository();

  @override
  Future<Either<Failure, (String, bool)>> validateSupervisor({
    required String username,
    required String password,
  }) async {
    return Right((username, true));
  }

  @override
  Future<Either<Failure, AuthSession?>> currentSession() {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> expireSession() {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, AuthSession>> login({
    required String username,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> logout() {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, AuthSession?>> refreshSession() {
    throw UnimplementedError();
  }
}

class _SettingsNotifierForTest extends SettingsNotifier {
  _SettingsNotifierForTest(AppSettings settings)
      : super(_SettingsRepositoryForTest(settings)) {
    state = settings;
  }
}

class _SettingsRepositoryForTest implements SettingsRepository {
  AppSettings settings;

  _SettingsRepositoryForTest(this.settings);

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async {
    this.settings = settings;
  }
}
