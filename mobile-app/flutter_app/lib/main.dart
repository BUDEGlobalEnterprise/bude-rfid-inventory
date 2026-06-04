import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
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

  runApp(
    ProviderScope(
      overrides: [
        syncBoxProvider.overrideWithValue(syncBox),
        tenantBoxProvider.overrideWithValue(tenantBox),
        activeTenantBoxProvider.overrideWithValue(activeTenantBox),
      ],
      child: const BudeInventoryApp(),
    ),
  );
}
