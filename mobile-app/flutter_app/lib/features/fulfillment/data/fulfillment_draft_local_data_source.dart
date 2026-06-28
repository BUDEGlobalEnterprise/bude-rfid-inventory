import 'dart:convert';

import 'package:hive/hive.dart';

import '../domain/fulfillment_draft.dart';

class FulfillmentDraftLocalDataSource {
  static const String boxName = 'bude.fulfillment.drafts';

  final Box<String> _box;
  FulfillmentDraftLocalDataSource(this._box);

  Future<void> save(FulfillmentDraft draft) {
    return _box.put(draft.salesOrder, jsonEncode(draft.toJson()));
  }

  FulfillmentDraft? get(String salesOrder) {
    final raw = _box.get(salesOrder);
    if (raw == null) return null;
    return FulfillmentDraft.fromJson(
      (jsonDecode(raw) as Map).cast<String, dynamic>(),
    );
  }

  Future<void> delete(String salesOrder) => _box.delete(salesOrder);
}
