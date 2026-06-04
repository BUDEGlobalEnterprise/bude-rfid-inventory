import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_repository_impl.dart';
import '../../domain/settings_repository.dart';

/// Kept as the home for future app-level preferences (theme, locale, etc.).
/// The ERP URL responsibility moved to `TenantNotifier` — see
/// `lib/features/tenant/presentation/providers/tenant_notifier.dart`.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(),
);
