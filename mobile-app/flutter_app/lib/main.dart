import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/sync/providers.dart';
import 'core/sync/sync_queue.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();

  await Hive.initFlutter();
  final syncBox = await Hive.openBox<String>(SyncQueue.boxName);

  runApp(
    ProviderScope(
      overrides: [
        syncBoxProvider.overrideWithValue(syncBox),
      ],
      child: const BudeInventoryApp(),
    ),
  );
}
