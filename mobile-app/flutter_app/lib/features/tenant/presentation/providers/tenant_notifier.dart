import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_config.dart';
import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../../settings/data/settings_repository_impl.dart';
import '../../../settings/domain/settings_repository.dart';
import '../../data/branding_remote_data_source.dart';
import '../../data/tenant_repository_impl.dart';
import '../../domain/branding.dart';
import '../../domain/tenant.dart';
import '../../domain/tenant_repository.dart';

// --- Hive box providers (overridden in main.dart after Hive init) ---

final tenantBoxProvider = Provider<Box<String>>((ref) {
  throw UnimplementedError('Override in ProviderScope after Hive init.');
});

final activeTenantBoxProvider = Provider<Box<String>>((ref) {
  throw UnimplementedError('Override in ProviderScope after Hive init.');
});

final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  return TenantRepositoryImpl(
    tenantBox: ref.watch(tenantBoxProvider),
    activeBox: ref.watch(activeTenantBoxProvider),
  );
});

/// Provider used only by the migration step; falls back to an in-memory repo
/// in tests if not overridden.
final legacySettingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(),
);

// --- State ---

sealed class TenantState extends Equatable {
  const TenantState();

  @override
  List<Object?> get props => [];
}

class TenantInitial extends TenantState {
  const TenantInitial();
}

class TenantLoading extends TenantState {
  const TenantLoading();
}

class TenantActive extends TenantState {
  final Tenant tenant;
  const TenantActive(this.tenant);

  @override
  List<Object?> get props => [tenant];
}

class TenantAbsent extends TenantState {
  const TenantAbsent();
}

// --- Notifier ---

final tenantNotifierProvider =
    StateNotifierProvider<TenantNotifier, TenantState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TenantNotifier(
    repository: ref.watch(tenantRepositoryProvider),
    legacySettings: ref.watch(legacySettingsRepositoryProvider),
    apiClient: apiClient,
    brandingSource: BrandingRemoteDataSourceImpl(apiClient.dio),
    uuid: const Uuid(),
  );
});

/// Derived view of the active tenant's cached branding. Null when no tenant
/// is active or no branding has been fetched yet.
final currentBrandingProvider = Provider<Branding?>((ref) {
  final state = ref.watch(tenantNotifierProvider);
  if (state is! TenantActive) return null;
  final raw = state.tenant.branding;
  if (raw == null) return null;
  return Branding.fromJson(raw);
});

class TenantNotifier extends StateNotifier<TenantState> {
  final TenantRepository repository;
  final SettingsRepository legacySettings;
  final dynamic apiClient; // ApiClient — typed as dynamic to avoid import cycle
  final BrandingRemoteDataSource brandingSource;
  final Uuid uuid;

  TenantNotifier({
    required this.repository,
    required this.legacySettings,
    required this.apiClient,
    required this.brandingSource,
    required this.uuid,
  }) : super(const TenantInitial());

  Tenant? get currentTenant {
    final s = state;
    return s is TenantActive ? s.tenant : null;
  }

  /// Called from SplashScreen on app boot. Migrates legacy settings URL if
  /// present, then resolves the active tenant (if any) and pushes its URL
  /// into AppConfig + ApiClient so subsequent requests use it.
  Future<void> bootstrap() async {
    state = const TenantLoading();
    await _maybeMigrateLegacy();
    final active = await repository.getActive();
    if (active == null) {
      AppConfig.setApiBaseUrlOverride(null);
      state = const TenantAbsent();
      return;
    }
    _applyToNetwork(active);
    state = TenantActive(active);
  }

  /// Persist a brand-new tenant from the onboarding wizard and activate it.
  Future<Tenant> createAndActivate({
    required String companyName,
    required String erpUrl,
  }) async {
    final now = DateTime.now().toUtc();
    final tenant = Tenant(
      id: uuid.v4(),
      companyName: companyName,
      erpUrl: erpUrl,
      createdAt: now,
      lastUsedAt: now,
    );
    await repository.save(tenant);
    await repository.setActive(tenant.id);
    _applyToNetwork(tenant);
    state = TenantActive(tenant);
    return tenant;
  }

  /// Touch lastUsedAt on every successful login.
  Future<void> markUsed() async {
    final active = currentTenant;
    if (active == null) return;
    final updated = active.copyWith(lastUsedAt: DateTime.now().toUtc());
    await repository.save(updated);
    state = TenantActive(updated);
  }

  /// Cache the latest branding payload on the active tenant.
  Future<void> updateBranding(Map<String, dynamic> branding) async {
    final active = currentTenant;
    if (active == null) return;
    final updated = active.copyWith(branding: branding);
    await repository.save(updated);
    state = TenantActive(updated);
  }

  /// Fetch fresh branding from the server and cache it. Swallow errors so
  /// branding refresh never blocks login or navigation — stale cache is fine.
  Future<void> refreshBranding() async {
    if (currentTenant == null) return;
    try {
      final branding = await brandingSource.fetch();
      await updateBranding(branding.toJson());
    } catch (_) {
      // No-op: keep whatever was cached.
    }
  }

  /// Reset the active connection — clears tenant + auth-relevant URL. The
  /// session itself is logged out by the caller (Settings screen).
  Future<void> clearActive() async {
    await repository.clearActive();
    AppConfig.setApiBaseUrlOverride(null);
    state = const TenantAbsent();
  }

  void _applyToNetwork(Tenant t) {
    AppConfig.setApiBaseUrlOverride(t.erpUrl);
    apiClient.setBaseUrl(AppConfig.apiBaseUrl);
  }

  /// One-shot migration: if no tenant exists but the old `SettingsRepository`
  /// has a URL persisted, create a Default tenant from it and remove the
  /// legacy entry.
  Future<void> _maybeMigrateLegacy() async {
    final existing = await repository.all();
    if (existing.isNotEmpty) return;
    final legacy = await legacySettings.load();
    final url = legacy.apiBaseUrl;
    if (url == null || url.trim().isEmpty) return;

    final now = DateTime.now().toUtc();
    final tenant = Tenant(
      id: uuid.v4(),
      companyName: 'Default',
      erpUrl: url.trim(),
      createdAt: now,
      lastUsedAt: now,
    );
    await repository.save(tenant);
    await repository.setActive(tenant.id);
    // Erase the legacy key so we never re-migrate.
    await legacySettings.save(legacy.copyWith(apiBaseUrl: ''));
  }
}
