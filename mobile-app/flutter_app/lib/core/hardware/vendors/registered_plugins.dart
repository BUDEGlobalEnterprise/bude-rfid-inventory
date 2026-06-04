import '../entities/device_info.dart';
import '../hardware_registry.dart';
import 'chainway/chainway_adapters.dart';
import 'generic/generic_uhf_adapter.dart';
import 'honeywell/honeywell_adapters.dart';
import 'urovo/urovo_adapters.dart';
import 'zebra/zebra_adapters.dart';

/// Compile-time list of known vendor plugins. Called from `main.dart` at app
/// start. Order matters: the first plugin whose `matches` returns true wins.
///
/// A real dynamic plugin marketplace would replace this list with a loader
/// that reads installed APKs / sideloaded packages and registers them at
/// runtime. Out of scope for this phase.
void registerBuiltInHardwarePlugins() {
  final registry = HardwareRegistry.instance;

  registry.register(
    HardwarePlugin(
      vendor: 'chainway',
      matches: (info) => _matchManufacturer(info, 'chainway'),
      barcodeFactory: () => ChainwayBarcodeAdapter(),
      rfidFactory: () => ChainwayRfidAdapter(),
    ),
  );

  registry.register(
    HardwarePlugin(
      vendor: 'zebra',
      matches: (info) => _matchManufacturer(info, 'zebra'),
      barcodeFactory: () => ZebraBarcodeAdapter(),
      rfidFactory: () => ZebraRfidAdapter(),
    ),
  );

  registry.register(
    HardwarePlugin(
      vendor: 'urovo',
      matches: (info) => _matchManufacturer(info, 'urovo'),
      barcodeFactory: () => UrovoBarcodeAdapter(),
      rfidFactory: () => UrovoRfidAdapter(),
    ),
  );

  registry.register(
    HardwarePlugin(
      vendor: 'honeywell',
      matches: (info) => _matchManufacturer(info, 'honeywell'),
      barcodeFactory: () => HoneywellBarcodeAdapter(),
      // Honeywell handhelds in this generation don't ship UHF RFID.
      rfidFactory: null,
    ),
  );

  // Last-resort RFID adapter — matches devices that have a detected built-in
  // RFID capability but no vendor-specific match. Real builds would replace
  // this with a concrete LLRP / BLE driver.
  registry.register(
    HardwarePlugin(
      vendor: 'generic',
      matches: (info) =>
          info.capabilities.contains(HardwareCapability.builtInRfidReader) ||
          info.capabilities.contains(HardwareCapability.bluetoothRfidReader) ||
          info.capabilities.contains(HardwareCapability.usbRfidReader),
      rfidFactory: () => GenericUhfRfidAdapter(),
    ),
  );
}

bool _matchManufacturer(DeviceInfo info, String vendor) =>
    info.manufacturer.toLowerCase().contains(vendor);
