import 'package:bude_inventory/core/ui/navigation_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('system manager can see manager destinations', () {
    final dests = navigationDestsFor(
      roles: const {'System Manager'},
      hiddenIds: const [],
    );

    expect(
      dests.map((d) => d.id),
      containsAll(['warehouses', 'masters', 'reports']),
    );
  });

  test('stock manager can see master data', () {
    final dests = navigationDestsFor(
      roles: const {'Stock Manager'},
      hiddenIds: const [],
    );

    expect(dests.map((d) => d.id), contains('masters'));
  });

  test('administrator username can see manager destinations without roles', () {
    final dests = navigationDestsFor(
      roles: const {},
      hiddenIds: const [],
      username: 'Administrator',
    );

    expect(dests.map((d) => d.id), contains('masters'));
    expect(
      canAccessManagerDestinations(const {}, username: 'Administrator'),
      isTrue,
    );
  });

  test('non-manager does not see manager-only destinations', () {
    final dests = navigationDestsFor(
      roles: const {'Stock User'},
      hiddenIds: const [],
    );

    expect(dests.map((d) => d.id), isNot(contains('reports')));
    expect(dests.map((d) => d.id), isNot(contains('masters')));
    expect(dests.map((d) => d.id), contains('transfer'));
  });

  test('hidden destinations are removed but mandatory destinations stay', () {
    final dests = navigationDestsFor(
      roles: const {'System Manager'},
      hiddenIds: const ['dashboard', 'settings', 'reports'],
    );
    final ids = dests.map((d) => d.id).toList();

    expect(ids, contains('dashboard'));
    expect(ids, contains('settings'));
    expect(ids, isNot(contains('reports')));
  });

  test('mobile navigation is capped to primary items plus settings', () {
    final dests = navigationDestsFor(
      roles: const {'System Manager'},
      hiddenIds: const [],
      mobile: true,
    );

    expect(dests.length, lessThanOrEqualTo(5));
    expect(dests.last.id, 'settings');
  });

  test('navigationBucketFor maps users to one bucket by priority', () {
    expect(navigationBucketFor(const {'System Manager'}), 'Stock Manager');
    expect(navigationBucketFor(const {'Stock Manager'}), 'Stock Manager');
    expect(navigationBucketFor(const {'Stock User'}), 'Stock User');
    expect(navigationBucketFor(const {}), 'Default');
    expect(
      navigationBucketFor(const {}, username: 'Administrator'),
      'Stock Manager',
    );
  });

  test('resolveNavHidden reads the matching bucket; null config hides nothing',
      () {
    final nav = {
      'buckets': {
        'Stock User': {
          'hidden': ['analytics', 'reports'],
        },
      },
    };
    expect(
      resolveNavHidden(nav, const {'Stock User'}),
      {'analytics', 'reports'},
    );
    // Manager bucket not configured → nothing hidden.
    expect(resolveNavHidden(nav, const {'Stock Manager'}), isEmpty);
    expect(resolveNavHidden(null, const {'Stock User'}), isEmpty);
  });

  test('per-role hidden ids drop from the rendered list', () {
    final nav = {
      'buckets': {
        'Stock User': {
          'hidden': ['alerts'],
        },
      },
    };
    final dests = navigationDestsFor(
      roles: const {'Stock User'},
      hiddenIds: resolveNavHidden(nav, const {'Stock User'}),
    );
    expect(dests.map((d) => d.id), isNot(contains('alerts')));
  });

  test('order reorders eligible destinations; unlisted keep relative order',
      () {
    final nav = {
      'order': ['settings', 'search', 'dashboard'],
    };
    final dests = navigationDestsFor(
      roles: const {'System Manager'},
      hiddenIds: const [],
      order: resolveNavOrder(nav),
    );
    final ids = dests.map((d) => d.id).toList();
    // The three named ids lead, in the configured order.
    expect(ids.sublist(0, 3), ['settings', 'search', 'dashboard']);
  });

  test('mandatory destinations stay even if hidden by a bucket', () {
    final nav = {
      'buckets': {
        'Default': {
          'hidden': ['dashboard', 'settings', 'alerts'],
        },
      },
    };
    final dests = navigationDestsFor(
      roles: const {},
      hiddenIds: resolveNavHidden(nav, const {}),
    );
    final ids = dests.map((d) => d.id);
    expect(ids, contains('dashboard'));
    expect(ids, contains('settings'));
    expect(ids, isNot(contains('alerts')));
  });
}
