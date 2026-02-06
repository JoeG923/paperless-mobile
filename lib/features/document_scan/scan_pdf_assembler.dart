import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> buildPdfBytesFromImages(List<Uint8List> images) {
  return compute(_buildPdfBytes, images);
}

Future<Uint8List> _buildPdfBytes(List<Uint8List> images) async {
  final doc = pw.Document();
  for (final bytes in images) {
    final img = pw.MemoryImage(bytes);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          img.width!.toDouble(),
          img.height!.toDouble(),
        ),
        build: (context) => pw.Image(img),
      ),
    );
  }
  return await doc.save();
}
