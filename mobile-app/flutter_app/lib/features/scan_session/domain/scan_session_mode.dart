enum ScanSessionMode { transfer, receipt, reconcile }

extension ScanSessionModeExt on ScanSessionMode {
  String get queryValue => name;

  static ScanSessionMode fromQuery(String? value) {
    return ScanSessionMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ScanSessionMode.transfer,
    );
  }
}
