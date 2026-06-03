import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../network/network_info_impl.dart';
import 'pending_operation.dart';
import 'sync_engine.dart';
import 'sync_queue.dart';

/// Set by `main()` after Hive opens the pending-ops box.
final syncBoxProvider = Provider<Box<String>>((ref) {
  throw UnimplementedError('Override in ProviderScope after Hive init.');
});

final syncQueueProvider = Provider<SyncQueue>((ref) {
  final box = ref.watch(syncBoxProvider);
  final queue = SyncQueue(box: box);
  ref.onDispose(() => queue.dispose());
  return queue;
});

final networkInfoProvider = Provider<NetworkInfoImpl>(
  (ref) => NetworkInfoImpl(),
);

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    queue: ref.watch(syncQueueProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
  ref.onDispose(() => engine.stop());
  return engine;
});

/// Live count of unresolved (pending + inflight + failed) ops.
final unresolvedOpCountProvider = StreamProvider<int>((ref) {
  return ref.watch(syncQueueProvider).unresolvedCountStream();
});

/// Live list of all ops, newest first when consumed.
final allOpsProvider = StreamProvider<List<PendingOperation>>((ref) {
  return ref.watch(syncQueueProvider).watchAll();
});
