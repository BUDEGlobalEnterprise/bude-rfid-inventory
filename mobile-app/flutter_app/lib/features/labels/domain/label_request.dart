import 'dart:convert';

import 'package:equatable/equatable.dart';

enum LabelKind { item, binLocation, pallet, receipt }

enum LabelFormat { pdf, zpl }

enum LabelSize { small50x25, medium75x50, large100x50 }

extension LabelKindX on LabelKind {
  String get displayName => switch (this) {
        LabelKind.item => 'Item',
        LabelKind.binLocation => 'Bin/location',
        LabelKind.pallet => 'Pallet',
        LabelKind.receipt => 'Receipt',
      };

  String get noun => switch (this) {
        LabelKind.item => 'item',
        LabelKind.binLocation => 'location',
        LabelKind.pallet => 'pallet',
        LabelKind.receipt => 'receipt',
      };
}

extension LabelFormatX on LabelFormat {
  String get displayName => switch (this) {
        LabelFormat.pdf => 'PDF',
        LabelFormat.zpl => 'ZPL',
      };
}

extension LabelSizeX on LabelSize {
  String get displayName => switch (this) {
        LabelSize.small50x25 => '50 x 25 mm',
        LabelSize.medium75x50 => '75 x 50 mm',
        LabelSize.large100x50 => '100 x 50 mm',
      };

  double get widthMm => switch (this) {
        LabelSize.small50x25 => 50,
        LabelSize.medium75x50 => 75,
        LabelSize.large100x50 => 100,
      };

  double get heightMm => switch (this) {
        LabelSize.small50x25 => 25,
        LabelSize.medium75x50 => 50,
        LabelSize.large100x50 => 50,
      };

  int get zplWidthDots => (widthMm * 8).round();

  int get zplHeightDots => (heightMm * 8).round();
}

class LabelRequest extends Equatable {
  final LabelKind kind;
  final LabelFormat format;
  final LabelSize size;
  final String title;
  final String primaryCode;
  final String? subtitle;
  final Map<String, String> metadata;
  final int quantity;
  final String? receiptOpId;
  final String? receiptServerRef;
  final Map<String, dynamic>? receiptPayload;

  const LabelRequest({
    required this.kind,
    required this.title,
    required this.primaryCode,
    this.format = LabelFormat.pdf,
    this.size = LabelSize.medium75x50,
    this.subtitle,
    this.metadata = const {},
    this.quantity = 1,
    this.receiptOpId,
    this.receiptServerRef,
    this.receiptPayload,
  });

  bool get usesQr => kind == LabelKind.receipt;

  String get barcodeData {
    if (!usesQr) return primaryCode;
    final payload = <String, dynamic>{
      'type': 'receipt',
      if (receiptOpId != null && receiptOpId!.isNotEmpty) 'op_id': receiptOpId,
      if (receiptServerRef != null && receiptServerRef!.isNotEmpty)
        'server_ref': receiptServerRef,
      'code': primaryCode,
      if (receiptPayload != null) 'payload': receiptPayload,
    };
    return jsonEncode(payload);
  }

  LabelRequest copyWith({
    LabelKind? kind,
    LabelFormat? format,
    LabelSize? size,
    String? title,
    String? primaryCode,
    Object? subtitle = _sentinel,
    Map<String, String>? metadata,
    int? quantity,
    Object? receiptOpId = _sentinel,
    Object? receiptServerRef = _sentinel,
    Object? receiptPayload = _sentinel,
  }) {
    return LabelRequest(
      kind: kind ?? this.kind,
      format: format ?? this.format,
      size: size ?? this.size,
      title: title ?? this.title,
      primaryCode: primaryCode ?? this.primaryCode,
      subtitle: subtitle == _sentinel ? this.subtitle : subtitle as String?,
      metadata: metadata ?? this.metadata,
      quantity: quantity ?? this.quantity,
      receiptOpId:
          receiptOpId == _sentinel ? this.receiptOpId : receiptOpId as String?,
      receiptServerRef: receiptServerRef == _sentinel
          ? this.receiptServerRef
          : receiptServerRef as String?,
      receiptPayload: receiptPayload == _sentinel
          ? this.receiptPayload
          : receiptPayload as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [
        kind,
        format,
        size,
        title,
        primaryCode,
        subtitle,
        metadata,
        quantity,
        receiptOpId,
        receiptServerRef,
        receiptPayload,
      ];
}

const _sentinel = Object();

String? validateLabelRequest(LabelRequest request) {
  if (request.quantity < 1) return 'Quantity must be at least 1.';
  if (request.primaryCode.trim().isEmpty) {
    return 'Enter a ${request.kind.noun} code before printing.';
  }
  return null;
}
