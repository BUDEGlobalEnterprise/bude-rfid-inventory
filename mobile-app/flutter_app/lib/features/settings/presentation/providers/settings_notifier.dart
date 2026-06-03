import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../authentication/presentation/providers/auth_notifier.dart';
import '../../data/settings_repository_impl.dart';
import '../../domain/app_settings.dart';
import '../../domain/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(),
);

final settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(
    repo: ref.watch(settingsRepositoryProvider),
    onApiUrlChanged: (url) {
      AppConfig.setApiBaseUrlOverride(url);
      ref.read(apiClientProvider).setBaseUrl(AppConfig.apiBaseUrl);
    },
  );
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsRepository repo;
  final void Function(String?) onApiUrlChanged;

  SettingsNotifier({required this.repo, required this.onApiUrlChanged})
      : super(const AppSettings());

  Future<void> bootstrap() async {
    final loaded = await repo.load();
    state = loaded;
    onApiUrlChanged(loaded.apiBaseUrl);
  }

  Future<void> setApiBaseUrl(String? url) async {
    final next = state.copyWith(apiBaseUrl: url);
    await repo.save(next);
    state = next;
    onApiUrlChanged(url);
  }
}
