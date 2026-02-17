import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_widget_repro_');
    Hive.init(tempDir.path);
    registerHiveAdapters();
    await Hive.openBox<GlobalSettings>(HiveBoxes.globalSettings);
    await Hive.openBox('localUserAccount');
    await Hive.box<GlobalSettings>(HiveBoxes.globalSettings).put(
      'SINGLE_VALUE',
      GlobalSettings(preferredLocaleSubtag: 'en', loggedInUserId: '1'),
    );
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('second setValue hangs in widget env?', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await Hive.box<GlobalSettings>(HiveBoxes.globalSettings).put(
      'SINGLE_VALUE',
      GlobalSettings(
        preferredLocaleSubtag: 'en',
        uploadPresetEnabled: true,
        uploadPresetTitleTemplate: 'Invoice',
      ),
    );
  });
}
