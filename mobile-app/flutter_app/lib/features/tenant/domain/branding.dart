import 'package:equatable/equatable.dart';

class Branding extends Equatable {
  final String? companyName;
  final String? logoPath; // relative ERPNext file path, e.g. "/files/acme.png"
  final String? address;
  final String? erpnextVersion;
  final String? budeApiVersion;
  final Map<String, bool> featureFlags;

  const Branding({
    this.companyName,
    this.logoPath,
    this.address,
    this.erpnextVersion,
    this.budeApiVersion,
    this.featureFlags = const {},
  });

  /// Absolute URL for the logo given the active ERP base URL, or null if no
  /// logo or no base URL.
  String? logoUrl(String? erpBaseUrl) {
    if (logoPath == null || logoPath!.isEmpty || erpBaseUrl == null) {
      return null;
    }
    final base = erpBaseUrl.endsWith('/')
        ? erpBaseUrl.substring(0, erpBaseUrl.length - 1)
        : erpBaseUrl;
    final path = logoPath!.startsWith('/') ? logoPath! : '/${logoPath!}';
    return '$base$path';
  }

  Map<String, dynamic> toJson() => {
        'company_name': companyName,
        'company_logo': logoPath,
        'company_address': address,
        'erpnext_version': erpnextVersion,
        'bude_api_version': budeApiVersion,
        'feature_flags': featureFlags,
      };

  static Branding fromJson(Map<String, dynamic> json) {
    final rawFlags = json['feature_flags'];
    final flags = <String, bool>{};
    if (rawFlags is Map) {
      rawFlags.forEach((k, v) {
        if (k is String && v is bool) flags[k] = v;
      });
    }
    return Branding(
      companyName: json['company_name'] as String?,
      logoPath: json['company_logo'] as String?,
      address: json['company_address'] as String?,
      erpnextVersion: json['erpnext_version'] as String?,
      budeApiVersion: json['bude_api_version'] as String?,
      featureFlags: flags,
    );
  }

  @override
  List<Object?> get props =>
      [companyName, logoPath, address, erpnextVersion, budeApiVersion, featureFlags];
}
