import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;
import 'package:paperless_mobile/features/document_scan/scan_pdf_assembler.dart';

void main() {
  test('buildPdfBytesFromImages returns a PDF document', () async {
    final image = im.Image(width: 10, height: 10);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgba(x, y, 255, 0, 0, 255);
      }
    }
    final jpg = Uint8List.fromList(im.encodeJpg(image));

    final pdfBytes = await buildPdfBytesFromImages([jpg]);

    final header = String.fromCharCodes(pdfBytes.take(4));
    expect(header, '%PDF');
  });
}
