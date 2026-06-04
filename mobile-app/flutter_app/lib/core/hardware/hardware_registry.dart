import 'adapters/barcode_adapter.dart';
import 'adapters/rfid_adapter.dart';
import 'entities/device_info.dart';

/// A "plugin": a bundle of factories that can produce adapters for a given
/// vendor. The HAL contract used by [HardwareRegistry].
///
/// Real vendor plugins live under `lib/core/hardware/vendors/<vendor>/`
/// and register themselves at app start by calling
/// `HardwareRegistry.instance.register(...)`. The registration list is
/// hardcoded in `main.dart` for now; a future phase can replace that with
/// a true dynamic plugin loader.
class HardwarePlugin {
  /// Vendor identifier — must match the `vendor` getter on the produced
  /// adapters and the value returned by [DeviceProbe] when this vendor's
  /// device is detected.
  final String vendor;

  /// Predicate used by [HardwareManager] to decide if this plugin should be
  /// selected for the detected device.
  final bool Function(DeviceInfo info) matches;

  /// Optional factories — null when the vendor doesn't provide that hardware.
  final BarcodeAdapter Function()? barcodeFactory;
  final RfidAdapter Function()? rfidFactory;

  const HardwarePlugin({
    required this.vendor,
    required this.matches,
    this.barcodeFactory,
    this.rfidFactory,
  });
}

/// In-memory registry of compile-time hardware plugins. Order of registration
/// is the order of evaluation when matching.
class HardwareRegistry {
  HardwareRegistry._();
  static final HardwareRegistry instance = HardwareRegistry._();

  final List<HardwarePlugin> _plugins = [];

  void register(HardwarePlugin plugin) {
    _plugins.add(plugin);
  }

  /// Replace the current registry contents. Useful for tests.
  void replaceAll(List<HardwarePlugin> plugins) {
    _plugins
      ..clear()
      ..addAll(plugins);
  }

  List<HardwarePlugin> get plugins => List.unmodifiable(_plugins);

  HardwarePlugin? findFor(DeviceInfo info) {
    for (final p in _plugins) {
      if (p.matches(info)) return p;
    }
    return null;
  }
}
