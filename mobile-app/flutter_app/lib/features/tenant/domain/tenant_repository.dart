import 'tenant.dart';

abstract class TenantRepository {
  Future<List<Tenant>> all();
  Future<Tenant?> getActive();
  Future<void> save(Tenant tenant);
  Future<void> setActive(String id);
  Future<void> clearActive();
  Future<void> delete(String id);
}
