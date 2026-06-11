import 'package:bude_inventory/core/hardware/entities/device_info.dart';
import 'package:bude_inventory/core/hardware/probes/android_device_probe.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('bude.hardware/probe');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mockReply(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async => handler(call));
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('parses the full happy-path payload from the platform', () async {
    mockReply((call) {
      expect(call.method, 'probe');
      return {
        'manufacturer': 'Chainway',
        'model': 'C72',
        'osVersion': '13',
        'capabilities': ['camera', 'builtInBarcodeScanner', 'builtInRfidReader'],
      };
    });

    final info = await AndroidDeviceProbe().probe();

    expect(info.manufacturer, 'Chainway');
    expect(info.model, 'C72');
    expect(info.osVersion, '13');
    expect(
      info.capabilities,
      containsAll(<HardwareCapability>{
        HardwareCapability.camera,
        HardwareCapability.builtInBarcodeScanner,
        HardwareCapability.builtInRfidReader,
      }),
    );
  });

  test('ignores unknown capability strings', () async {
    mockReply(
      (_) => {
        'manufacturer': 'Honeywell',
        'model': 'CT40',
        'capabilities': ['camera', 'something_unknown', 'builtInBarcodeScanner'],
      },
    );

    final info = await AndroidDeviceProbe().probe();

    expect(info.capabilities, {
      HardwareCapability.camera,
      HardwareCapability.builtInBarcodeScanner,
    });
  });

  test('falls back to "unknown" when the plugin is not registered', () async {
    // No mock installed → MissingPluginException.
    final info = await AndroidDeviceProbe().probe();

    expect(info.manufacturer, 'unknown');
    expect(info.model, 'unknown');
    expect(info.capabilities, {HardwareCapability.camera});
  });

  test('falls back to "unknown" when the platform throws', () async {
    mockReply((_) => throw PlatformException(code: 'boom'));

    final info = await AndroidDeviceProbe().probe();

    expect(info.isUnknownVendor, isTrue);
  });

  test('tolerates a null payload', () async {
    mockReply((_) => null);

    final info = await AndroidDeviceProbe().probe();

    expect(info.manufacturer, 'unknown');
  });

  test('tolerates a partially populated payload', () async {
    mockReply(
      (_) => {
        'manufacturer': 'Urovo',
        // model + osVersion + capabilities all absent
      },
    );

    final info = await AndroidDeviceProbe().probe();

    expect(info.manufacturer, 'Urovo');
    expect(info.model, 'unknown');
    expect(info.osVersion, isNull);
    expect(info.capabilities, isEmpty);
  });
}
