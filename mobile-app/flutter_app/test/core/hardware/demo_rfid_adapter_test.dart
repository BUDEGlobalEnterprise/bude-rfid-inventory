import 'package:bude_inventory/core/hardware/adapters/hardware_exceptions.dart';
import 'package:bude_inventory/core/hardware/adapters/rfid_adapter.dart';
import 'package:bude_inventory/core/hardware/vendors/demo/demo_rfid_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connects and reads deterministic EPCs', () async {
    final adapter = DemoRfidAdapter(epcs: const ['EPC-1', 'EPC-2']);

    expect(adapter.vendor, 'demo');
    expect(adapter.isConnected, isFalse);

    await adapter.connect();
    expect(adapter.isConnected, isTrue);

    final first = await adapter.readTag();
    final second = await adapter.readTag();
    final third = await adapter.readTag();

    expect(first?.epc, 'EPC-1');
    expect(second?.epc, 'EPC-2');
    expect(third?.epc, 'EPC-1');
  });

  test('inventory stream emits fake tags until stopped', () async {
    final adapter = DemoRfidAdapter(
      epcs: const ['EPC-1', 'EPC-2'],
      inventoryInterval: const Duration(milliseconds: 10),
    );
    await adapter.connect();

    final tags = <String>[];
    final sub = adapter.tagStream.listen((tag) => tags.add(tag.epc));
    await adapter.startInventory();
    await Future<void>.delayed(const Duration(milliseconds: 35));
    await adapter.stopInventory();
    final countAfterStop = tags.length;
    await Future<void>.delayed(const Duration(milliseconds: 25));

    await sub.cancel();
    await adapter.dispose();

    expect(tags, isNotEmpty);
    expect(tags, containsAll(['EPC-1', 'EPC-2']));
    expect(tags.length, countAfterStop);
  });

  test('write lock and kill are not supported', () async {
    final adapter = DemoRfidAdapter();

    expect(
      () => adapter.writeTagEpc('EPC-X'),
      throwsA(isA<HardwareOperationException>()),
    );
    expect(
      () => adapter.lockTag(
        bank: RfidMemoryBank.epc,
        accessPassword: '00000000',
      ),
      throwsA(isA<HardwareOperationException>()),
    );
    expect(
      () => adapter.killTag(killPassword: '00000000'),
      throwsA(isA<HardwareOperationException>()),
    );
  });
}
