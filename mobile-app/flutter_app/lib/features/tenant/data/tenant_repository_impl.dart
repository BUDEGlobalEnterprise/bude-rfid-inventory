import 'package:hive/hive.dart';

import '../domain/tenant.dart';
import '../domain/tenant_repository.dart';

class TenantRepositoryImpl implements TenantRepository {
  static const String tenantBoxName = 'bude.tenant.list';
  static const String activeBoxName = 'bude.tenant.active_id';
  static const String _activeKey = 'active';

  final Box<String> tenantBox;
  final Box<String> activeBox;

  TenantRepositoryImpl({
    required this.tenantBox,
    required this.activeBox,
  });

  @override
  Future<List<Tenant>> all() async {
    return tenantBox.values.map(Tenant.decode).toList()
      ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
  }

  @override
  Future<Tenant?> getActive() async {
    final id = activeBox.get(_activeKey);
    if (id == null) return null;
    final raw = tenantBox.get(id);
    if (raw == null) return null;
    return Tenant.decode(raw);
  }

  @override
  Future<void> save(Tenant tenant) async {
    await tenantBox.put(tenant.id, tenant.encode());
  }

  @override
  Future<void> setActive(String id) async {
    if (tenantBox.get(id) == null) {
      throw StateError('Cannot activate unknown tenant id: $id');
    }
    await activeBox.put(_activeKey, id);
  }

  @override
  Future<void> clearActive() async {
    await activeBox.delete(_activeKey);
  }

  @override
  Future<void> delete(String id) async {
    await tenantBox.delete(id);
    final activeId = activeBox.get(_activeKey);
    if (activeId == id) {
      await activeBox.delete(_activeKey);
    }
  }
}
