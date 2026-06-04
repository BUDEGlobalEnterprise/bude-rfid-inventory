import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/hardware/providers.dart';
import 'core/hardware/vendors/registered_plugins.dart';
import 'core/sync/providers.dart';
import 'core/sync/sync_queue.dart';
import 'features/tenant/data/tenant_repository_impl.dart';
import 'features/tenant/presentation/providers/tenant_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();

  await Hive.initFlutter();
  final syncBox = await Hive.openBox<String>(SyncQueue.boxName);
  final tenantBox =
      await Hive.openBox<String>(TenantRepositoryImpl.tenantBoxName);
  final activeTenantBox =
      await Hive.openBox<String>(TenantRepositoryImpl.activeBoxName);

  // Register all known vendor plugins, then bootstrap the manager (probes the
  // device + selects adapters). Camera scanner is wired in as the fallback so
  // unknown devices still work.
  registerBuiltInHardwarePlugins();
  final hardwareManager = await bootstrapHardwareManager();

  runApp(
    ProviderScope(
      overrides: [
        syncBoxProvider.overrideWithValue(syncBox),
        tenantBoxProvider.overrideWithValue(tenantBox),
        activeTenantBoxProvider.overrideWithValue(activeTenantBox),
        hardwareManagerProvider.overrideWithValue(hardwareManager),
      ],
      child: const BudeInventoryApp(),
    ),
  );
}
