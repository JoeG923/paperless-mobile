import 'dart:typed_data';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;
import 'package:paperless_mobile/features/document_scan/scan_pdf_assembler.dart';

Future<File> _writeTemporaryImage(Directory directory, String filename) async {
  final image = im.Image(width: 8, height: 8);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(x, y, 0, 0, 0, 255);
    }
  }
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(Uint8List.fromList(im.encodePng(image)), flush: true);
  return file;
}

Future<File> _writeTemporaryRawFile(
  Directory directory,
  String filename,
  List<int> bytes,
) async {
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

void main() {
  late Directory tempDir;
  late List<File> createdFiles;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('scan-assembler-test-');
    createdFiles = [];
  });

  tearDown(() async {
    for (final file in createdFiles) {
      if (await file.exists()) {
        await file.delete();
      }
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

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

  test('assembleScannedFiles keeps single file extension and bytes', () async {
    final file = await _writeTemporaryImage(tempDir, 'scan.png');
    createdFiles.add(file);
    final assembled = await assembleScannedFiles([file], forcePdf: false);

    final original = await file.readAsBytes();

    expect(assembled.extension, '.png');
    expect(assembled.bytes, equals(original));
  });

  test(
    'assembleScannedFiles preserves extension for single file without pdf',
    () async {
      final file = await _writeTemporaryImage(tempDir, 'scan');
      createdFiles.add(file);
      final assembled = await assembleScannedFiles([file], forcePdf: false);

      final original = await file.readAsBytes();

      expect(assembled.extension, isEmpty);
      expect(assembled.bytes, equals(original));
    },
  );

  test(
    'assembleScannedFiles forces pdf output for one file when requested',
    () async {
      final file = await _writeTemporaryImage(tempDir, 'scan_single.jpg');
      createdFiles.add(file);
      final assembled = await assembleScannedFiles([file], forcePdf: true);

      final header = String.fromCharCodes(assembled.bytes.take(4));
      expect(assembled.extension, '.pdf');
      expect(header, '%PDF');
    },
  );

  test('assembleScannedFiles turns multiple scans into one PDF', () async {
    final first = await _writeTemporaryImage(tempDir, 'first.png');
    final second = await _writeTemporaryImage(tempDir, 'second.png');
    createdFiles.addAll([first, second]);

    final assembled = await assembleScannedFiles([
      first,
      second,
    ], forcePdf: false);

    final header = String.fromCharCodes(assembled.bytes.take(4));
    expect(assembled.extension, '.pdf');
    expect(header, '%PDF');
    expect(assembled.bytes.isNotEmpty, isTrue);
  });

  test('assembleScannedFiles rejects empty scan list', () async {
    expect(() => assembleScannedFiles([]), throwsA(isA<ArgumentError>()));
  });

  test(
    'assembleScannedFiles forces pdf when enabled even for mixed extensions',
    () async {
      final first = await _writeTemporaryImage(tempDir, 'first.png');
      final second = await _writeTemporaryImage(tempDir, 'second.jpeg');
      createdFiles.addAll([first, second]);

      final assembled = await assembleScannedFiles([
        first,
        second,
      ], forcePdf: true);

      final header = String.fromCharCodes(assembled.bytes.take(4));
      expect(assembled.extension, '.pdf');
      expect(header, '%PDF');
    },
  );

  test(
    'assembleScannedFiles throws when forcing pdf from corrupt image bytes',
    () async {
      final invalidFile = await _writeTemporaryRawFile(tempDir, 'invalid.jpg', [
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
      createdFiles.add(invalidFile);

      await expectLater(
        () => assembleScannedFiles([invalidFile], forcePdf: true),
        throwsA(isA<Exception>()),
      );
    },
  );
}
