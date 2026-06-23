import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'item_search_notifier.dart';

final itemGroupsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  return ref.watch(itemRemoteDataSourceProvider).listGroups();
});
