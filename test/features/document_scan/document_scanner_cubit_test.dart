import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_mobile/features/document_scan/cubit/document_scanner_cubit.dart';
import 'package:paperless_mobile/features/notifications/services/local_notification_service.dart';

void main() {
  late Directory tempDir;
  late File firstScan;
  late File secondScan;
  late DocumentScannerCubit cubit;

  Future<File> createScanFile(String name) async {
    final file = File('${tempDir.path}/$name.jpg');
    await file.writeAsBytes(List<int>.generate(8, (i) => i), flush: true);
    return file;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('scanner_cubit_test_');
    firstScan = await createScanFile('first');
    secondScan = await createScanFile('second');
    cubit = DocumentScannerCubit(LocalNotificationService());
  });

  tearDown(() async {
    await cubit.close();
    if (await firstScan.exists()) {
      await firstScan.delete();
    }
    if (await secondScan.exists()) {
      await secondScan.delete();
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('addScan appends to existing scanned files list', () {
    cubit.addScan(firstScan);
    cubit.addScan(secondScan);

    expect(cubit.state.scans, [firstScan, secondScan]);
    expect(cubit.state.scans.length, 2);
  });

  test('removeScan removes file from state and deletes file', () async {
    cubit.addScan(firstScan);
    cubit.addScan(secondScan);

    await cubit.removeScan(firstScan);

    expect(cubit.state.scans, [secondScan]);
    expect(await firstScan.exists(), isFalse);
    expect(await secondScan.exists(), isTrue);
  });

  test('reset clears scans and deletes temporary files', () async {
    cubit.addScan(firstScan);
    cubit.addScan(secondScan);

    await cubit.reset();

    expect(cubit.state.scans, isEmpty);
    expect(await firstScan.exists(), isFalse);
    expect(await secondScan.exists(), isFalse);
  });
}
