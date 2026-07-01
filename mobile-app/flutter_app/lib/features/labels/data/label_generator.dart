import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/label_request.dart';

class LabelGenerator {
  const LabelGenerator._();

  static Future<Uint8List> buildPdf(LabelRequest request) async {
    final document = pw.Document();
    final pageFormat = PdfPageFormat(
      request.size.widthMm * PdfPageFormat.mm,
      request.size.heightMm * PdfPageFormat.mm,
      marginAll: 2 * PdfPageFormat.mm,
    );

    for (var i = 0; i < request.quantity; i++) {
      document.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (_) => _PdfLabel(request: request),
        ),
      );
    }

    return document.save();
  }

  static String buildZpl(LabelRequest request) {
    final buffer = StringBuffer();
    for (var i = 0; i < request.quantity; i++) {
      buffer
        ..writeln('^XA')
        ..writeln('^CI28')
        ..writeln('^PW${request.size.zplWidthDots}')
        ..writeln('^LL${request.size.zplHeightDots}')
        ..writeln('^FO24,22^A0N,32,32^FD${_zplText(request.title)}^FS')
        ..writeln('^FO24,58^A0N,22,22^FD${_zplText(request.primaryCode)}^FS');

      var y = 88;
      final subtitle = request.subtitle?.trim();
      if (subtitle != null && subtitle.isNotEmpty) {
        buffer.writeln('^FO24,$y^A0N,20,20^FD${_zplText(subtitle)}^FS');
        y += 26;
      }

      for (final entry in request.metadata.entries.take(4)) {
        final value = '${entry.key}: ${entry.value}';
        if (value.trim().isEmpty) continue;
        buffer.writeln('^FO24,$y^A0N,18,18^FD${_zplText(value)}^FS');
        y += 24;
      }

      final barcodeY = request.size == LabelSize.small50x25 ? 104 : y + 8;
      if (request.usesQr) {
        buffer
          ..writeln('^FO24,$barcodeY^BQN,2,5')
          ..writeln('^FDLA,${_zplText(request.barcodeData)}^FS');
      } else {
        buffer
          ..writeln('^FO24,$barcodeY^BCN,82,Y,N,N')
          ..writeln('^FD${_zplText(request.barcodeData)}^FS');
      }
      buffer.writeln('^XZ');
    }
    return buffer.toString();
  }

  static Future<void> printPdf(LabelRequest request) async {
    final bytes = await buildPdf(request);
    await Printing.layoutPdf(
      name: _fileStem(request),
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> sharePdf(LabelRequest request) async {
    final bytes = await buildPdf(request);
    final file = await _writeBytes(
      filename: '${_fileStem(request)}.pdf',
      bytes: bytes,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Bude label ${request.primaryCode}',
    );
  }

  static Future<void> shareZpl(LabelRequest request) async {
    final zpl = buildZpl(request);
    final file = await _writeText(
      filename: '${_fileStem(request)}.zpl',
      text: zpl,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/plain')],
      subject: 'Bude ZPL label ${request.primaryCode}',
    );
  }

  static Future<File> _writeBytes({
    required String filename,
    required Uint8List bytes,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    return file.writeAsBytes(bytes, flush: true);
  }

  static Future<File> _writeText({
    required String filename,
    required String text,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    return file.writeAsString(text, flush: true);
  }
}

class _PdfLabel extends pw.StatelessWidget {
  final LabelRequest request;

  _PdfLabel({required this.request});

  @override
  pw.Widget build(pw.Context context) {
    final barcodeHeight = request.usesQr
        ? request.size.heightMm * 0.42 * PdfPageFormat.mm
        : request.size.heightMm * 0.26 * PdfPageFormat.mm;

    return pw.Container(
      width: double.infinity,
      height: double.infinity,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            request.title,
            maxLines: 1,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            request.primaryCode,
            maxLines: 1,
            style: const pw.TextStyle(fontSize: 9),
          ),
          if ((request.subtitle ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              request.subtitle!,
              maxLines: 1,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
          if (request.metadata.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Wrap(
              spacing: 4,
              runSpacing: 1,
              children: [
                for (final entry in request.metadata.entries.take(5))
                  pw.Text(
                    '${entry.key}: ${entry.value}',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
              ],
            ),
          ],
          pw.Spacer(),
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: request.usesQr
                  ? pw.Barcode.qrCode()
                  : pw.Barcode.code128(),
              data: request.barcodeData,
              width: request.usesQr ? barcodeHeight : double.infinity,
              height: barcodeHeight,
              drawText: !request.usesQr,
            ),
          ),
        ],
      ),
    );
  }
}

String _fileStem(LabelRequest request) {
  final safeCode = request.primaryCode
      .replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final code = safeCode.isEmpty ? 'label' : safeCode;
  return 'bude_label_${request.kind.name}_$code';
}

String _zplText(String value) {
  return value
      .replaceAll('\r', ' ')
      .replaceAll('\n', ' ')
      .replaceAll('^', ' ')
      .replaceAll('~', ' ')
      .trim();
}
