import 'package:bude_inventory/features/company/domain/entities/company.dart';
import 'package:bude_inventory/features/company/presentation/providers/company_providers.dart';
import 'package:bude_inventory/features/settings/domain/app_settings.dart';
import 'package:bude_inventory/features/settings/domain/settings_repository.dart';
import 'package:bude_inventory/features/settings/presentation/providers/settings_notifier.dart';
import 'package:bude_inventory/features/transfer/data/warehouse_remote_data_source.dart';
import 'package:bude_inventory/features/transfer/presentation/providers/transfer_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('warehousesProvider passes active company to the remote source',
      () async {
    final remote = _WarehouseRemoteForTest(['Stores - A']);
    final container = ProviderContainer(
      overrides: [
        settingsNotifierProvider.overrideWith(
          (ref) => _SettingsNotifierForTest(
            const AppSettings(activeCompany: 'Company A'),
          ),
        ),
        warehouseRemoteProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);

    final warehouses = await container.read(warehousesProvider.future);

    expect(warehouses, ['Stores - A']);
    expect(remote.company, 'Company A');
  });

  test('warehouseLocationsProvider passes warehouse and active company',
      () async {
    final remote = _WarehouseRemoteForTest(['Stores - A'])
      ..locations = ['Rack 1 - A'];
    final container = ProviderContainer(
      overrides: [
        settingsNotifierProvider.overrideWith(
          (ref) => _SettingsNotifierForTest(
            const AppSettings(activeCompany: 'Company A'),
          ),
        ),
        warehouseRemoteProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);

    final locations =
        await container.read(warehouseLocationsProvider('Stores - A').future);

    expect(locations, ['Rack 1 - A']);
    expect(remote.locationWarehouse, 'Stores - A');
    expect(remote.locationCompany, 'Company A');
  });

  test('changing transfer warehouses clears stale locations', () {
    final notifier = TransferDraftNotifier()
      ..setSource('Stores - A')
      ..setSourceLocation('Rack 1 - A')
      ..setTarget('Dispatch - A')
      ..setTargetLocation('Staging - A');

    notifier.setSource('Stores - B');
    notifier.setTarget('Dispatch - B');

    expect(notifier.state.sourceLocation, isNull);
    expect(notifier.state.targetLocation, isNull);
  });

  test(
      'operationCompanyProvider uses sole ERPNext company when no active company is set',
      () async {
    final container = ProviderContainer(
      overrides: [
        settingsNotifierProvider.overrideWith(
          (ref) => _SettingsNotifierForTest(const AppSettings()),
        ),
        companiesProvider.overrideWith(
          (ref) async => const [
            Company(name: 'Only Co', companyName: 'Only Company'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    final company = await container.read(operationCompanyProvider.future);

    expect(company, 'Only Co');
  });

  test('operationCompanyProvider requires selection for multiple companies',
      () async {
    final container = ProviderContainer(
      overrides: [
        settingsNotifierProvider.overrideWith(
          (ref) => _SettingsNotifierForTest(const AppSettings()),
        ),
        companiesProvider.overrideWith(
          (ref) async => const [
            Company(name: 'Company A', companyName: 'Company A'),
            Company(name: 'Company B', companyName: 'Company B'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(operationCompanyProvider.future),
      throwsA(isA<CompanySelectionRequiredException>()),
    );
  });
}

class _WarehouseRemoteForTest extends WarehouseRemoteDataSource {
  final List<String> warehouses;
  List<String> locations = const [];
  String? company;
  String? locationWarehouse;
  String? locationCompany;

  _WarehouseRemoteForTest(this.warehouses) : super(Dio());

  @override
  Future<List<String>> list({int limit = 100, String? company}) async {
    this.company = company;
    return warehouses;
  }

  @override
  Future<List<String>> listLocations(
    String warehouse, {
    int limit = 100,
    String? company,
  }) async {
    locationWarehouse = warehouse;
    locationCompany = company;
    return locations;
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
