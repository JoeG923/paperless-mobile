import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;

Future<Uint8List> buildPdfBytesFromImages(List<Uint8List> images) {
  return compute(_buildPdfBytes, images);
}

Future<ScannedAssembledFile> assembleScannedFiles(
  List<File> files, {
  bool forcePdf = false,
}) async {
  if (files.isEmpty) {
    throw ArgumentError('At least one scanned file is required');
  }
  if (files.length == 1 && !forcePdf) {
    final file = files.single;
    return ScannedAssembledFile(
      extension: p.extension(file.path),
      bytes: await file.readAsBytes(),
    );
  }

  final imageBytes = <Uint8List>[];
  for (final file in files) {
    imageBytes.add(await file.readAsBytes());
  }
  final pdfBytes = await buildPdfBytesFromImages(imageBytes);
  return ScannedAssembledFile(extension: '.pdf', bytes: pdfBytes);
}

class ScannedAssembledFile {
  final String extension;
  final Uint8List bytes;

  const ScannedAssembledFile({required this.extension, required this.bytes});
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
