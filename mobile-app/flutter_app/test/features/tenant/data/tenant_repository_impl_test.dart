import 'package:bude_inventory/features/tenant/data/tenant_repository_impl.dart';
import 'package:bude_inventory/features/tenant/domain/tenant.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_box.dart';

void main() {
  late FakeBox tenantBox;
  late FakeBox activeBox;
  late TenantRepositoryImpl repo;

  setUp(() {
    tenantBox = FakeBox();
    activeBox = FakeBox();
    repo = TenantRepositoryImpl(tenantBox: tenantBox, activeBox: activeBox);
  });

  Tenant make(String id, {DateTime? lastUsed}) => Tenant(
        id: id,
        companyName: 'Co $id',
        erpUrl: 'https://$id.example.com',
        createdAt: DateTime.utc(2026, 1, 1),
        lastUsedAt: lastUsed ?? DateTime.utc(2026, 1, 1),
      );

  test('save then getActive returns null until setActive called', () async {
    final t = make('a');
    await repo.save(t);
    expect(await repo.getActive(), isNull);

    await repo.setActive('a');
    expect((await repo.getActive())!.id, 'a');
  });

  test('all returns tenants sorted by lastUsedAt desc', () async {
    await repo.save(make('a', lastUsed: DateTime.utc(2026, 1, 1)));
    await repo.save(make('b', lastUsed: DateTime.utc(2026, 3, 1)));
    await repo.save(make('c', lastUsed: DateTime.utc(2026, 2, 1)));

    final ids = (await repo.all()).map((t) => t.id).toList();
    expect(ids, ['b', 'c', 'a']);
  });

  test('setActive throws on unknown id', () async {
    expect(
      () => repo.setActive('missing'),
      throwsA(isA<StateError>()),
    );
  });

  test('clearActive removes the active pointer but keeps the tenant', () async {
    await repo.save(make('a'));
    await repo.setActive('a');
    await repo.clearActive();

    expect(await repo.getActive(), isNull);
    expect((await repo.all()).map((t) => t.id), ['a']);
  });

  test('delete clears active pointer when the deleted tenant was active',
      () async {
    await repo.save(make('a'));
    await repo.setActive('a');
    await repo.delete('a');

    expect(await repo.getActive(), isNull);
    expect(await repo.all(), isEmpty);
  });

  test('Tenant.copyWith with clearBranding=true drops cached branding',
      () async {
    final t = make('a').copyWith(branding: {'company_name': 'Acme'});
    await repo.save(t);
    final reread = (await repo.all()).first;
    expect(reread.branding!['company_name'], 'Acme');

    final cleared = reread.copyWith(clearBranding: true);
    await repo.save(cleared);
    expect((await repo.all()).first.branding, isNull);
  });
}
