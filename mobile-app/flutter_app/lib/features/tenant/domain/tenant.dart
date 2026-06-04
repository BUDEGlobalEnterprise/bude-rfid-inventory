import 'dart:convert';

import 'package:equatable/equatable.dart';

/// A persisted ERP connection profile. One install can store multiple tenants
/// (data model allows it) but only one is active at a time in this phase.
class Tenant extends Equatable {
  final String id;
  final String companyName;
  final String erpUrl;
  final DateTime createdAt;
  final DateTime lastUsedAt;

  /// Optional cached branding for the connection-info screen + app bar.
  /// Stored as a JSON map to avoid coupling this entity to a Branding type
  /// declared in Slice C — typed access lives in BrandingRepository.
  final Map<String, dynamic>? branding;

  const Tenant({
    required this.id,
    required this.companyName,
    required this.erpUrl,
    required this.createdAt,
    required this.lastUsedAt,
    this.branding,
  });

  Tenant copyWith({
    String? companyName,
    String? erpUrl,
    DateTime? lastUsedAt,
    Map<String, dynamic>? branding,
    bool clearBranding = false,
  }) {
    return Tenant(
      id: id,
      companyName: companyName ?? this.companyName,
      erpUrl: erpUrl ?? this.erpUrl,
      createdAt: createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      branding: clearBranding ? null : (branding ?? this.branding),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyName': companyName,
        'erpUrl': erpUrl,
        'createdAt': createdAt.toIso8601String(),
        'lastUsedAt': lastUsedAt.toIso8601String(),
        'branding': branding,
      };

  static Tenant fromJson(Map<String, dynamic> json) {
    return Tenant(
      id: json['id'] as String,
      companyName: json['companyName'] as String,
      erpUrl: json['erpUrl'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
      branding: json['branding'] == null
          ? null
          : (json['branding'] as Map).cast<String, dynamic>(),
    );
  }

  String encode() => jsonEncode(toJson());
  static Tenant decode(String raw) =>
      fromJson(jsonDecode(raw) as Map<String, dynamic>);

  @override
  List<Object?> get props => [
        id,
        companyName,
        erpUrl,
        createdAt,
        lastUsedAt,
        branding,
      ];
}
