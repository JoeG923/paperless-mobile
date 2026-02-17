import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';

late Directory tempDir;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('hive_setall_');
    Hive.init(tempDir.path);
    registerHiveAdapters();
    await Hive.openBox<GlobalSettings>(HiveBoxes.globalSettings);
    await Hive.box<GlobalSettings>(HiveBoxes.globalSettings).put(
      'SINGLE_VALUE',
      GlobalSettings(
        preferredLocaleSubtag: 'en',
        uploadPresetEnabled: true,
        uploadPresetTitleTemplate: 'Invoice',
      ),
    );
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('write in setUpAll', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  });
}
