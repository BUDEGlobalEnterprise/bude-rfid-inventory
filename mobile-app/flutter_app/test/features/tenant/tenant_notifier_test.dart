import 'package:bude_inventory/core/config/app_config.dart';
import 'package:bude_inventory/features/settings/domain/app_settings.dart';
import 'package:bude_inventory/features/settings/domain/settings_repository.dart';
import 'package:bude_inventory/features/tenant/data/branding_remote_data_source.dart';
import 'package:bude_inventory/features/tenant/data/tenant_repository_impl.dart';
import 'package:bude_inventory/features/tenant/domain/branding.dart';
import 'package:bude_inventory/features/tenant/presentation/providers/tenant_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/fake_box.dart';

class _MockBranding extends Mock implements BrandingRemoteDataSource {}

class _FakeApiClient {
  String? lastBaseUrl;
  void setBaseUrl(String url) => lastBaseUrl = url;
}

class _InMemorySettings implements SettingsRepository {
  AppSettings _state = const AppSettings();
  @override
  Future<AppSettings> load() async => _state;
  @override
  Future<void> save(AppSettings settings) async => _state = settings;
}

void main() {
  setUpAll(() {
    AppConfig.load(); // initializes _env
  });

  late TenantRepositoryImpl repo;
  late _MockBranding branding;
  late _FakeApiClient apiClient;
  late _InMemorySettings legacy;
  late TenantNotifier notifier;

  setUp(() {
    repo = TenantRepositoryImpl(
      tenantBox: FakeBox(),
      activeBox: FakeBox(),
    );
    branding = _MockBranding();
    apiClient = _FakeApiClient();
    legacy = _InMemorySettings();
    notifier = TenantNotifier(
      repository: repo,
      legacySettings: legacy,
      apiClient: apiClient,
      brandingSource: branding,
      uuid: const Uuid(),
    );
  });

  test('bootstrap with no tenant + no legacy → TenantAbsent', () async {
    await notifier.bootstrap();
    expect(notifier.state, isA<TenantAbsent>());
    expect(apiClient.lastBaseUrl, isNull);
  });

  test('bootstrap migrates legacy URL into a Default tenant', () async {
    await legacy.save(const AppSettings(apiBaseUrl: 'https://legacy.example'));
    await notifier.bootstrap();

    expect(notifier.state, isA<TenantActive>());
    final t = (notifier.state as TenantActive).tenant;
    expect(t.companyName, 'Default');
    expect(t.erpUrl, 'https://legacy.example');
    expect(apiClient.lastBaseUrl, 'https://legacy.example');

    // Legacy URL erased so we never re-migrate.
    expect((await legacy.load()).apiBaseUrl, '');
  });

  test('createAndActivate persists + activates + pushes to ApiClient',
      () async {
    final t = await notifier.createAndActivate(
      companyName: 'Acme',
      erpUrl: 'https://acme.example',
    );

    expect(t.companyName, 'Acme');
    expect((await repo.getActive())!.id, t.id);
    expect(apiClient.lastBaseUrl, 'https://acme.example');
    expect(notifier.state, isA<TenantActive>());
  });

  test('refreshBranding caches Branding json on the active tenant', () async {
    await notifier.createAndActivate(
      companyName: 'Acme',
      erpUrl: 'https://acme.example',
    );
    when(() => branding.fetch()).thenAnswer(
      (_) async => const Branding(
        companyName: 'Acme Inc',
        logoPath: '/files/acme.png',
        erpnextVersion: '15.0.0',
        budeApiVersion: '0.1.0',
      ),
    );

    await notifier.refreshBranding();

    final t = (notifier.state as TenantActive).tenant;
    expect(t.branding!['company_name'], 'Acme Inc');
    expect(t.branding!['erpnext_version'], '15.0.0');
  });

  test('refreshBranding swallows remote errors and keeps existing cache',
      () async {
    await notifier.createAndActivate(
      companyName: 'Acme',
      erpUrl: 'https://acme.example',
    );
    await notifier.updateBranding({'company_name': 'Stale'});

    when(() => branding.fetch()).thenThrow(Exception('boom'));

    await notifier.refreshBranding();

    final t = (notifier.state as TenantActive).tenant;
    expect(t.branding!['company_name'], 'Stale');
  });

  test('clearActive resets state and clears URL override', () async {
    await notifier.createAndActivate(
      companyName: 'Acme',
      erpUrl: 'https://acme.example',
    );
    expect(notifier.state, isA<TenantActive>());

    await notifier.clearActive();

    expect(notifier.state, isA<TenantAbsent>());
    // AppConfig override cleared → falls back to env default.
    expect(AppConfig.apiBaseUrl, AppConfig.env.apiBaseUrl);
  });
}
