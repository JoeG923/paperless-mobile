import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('single hive put in widget env before pump', (
    WidgetTester tester,
  ) async {
    final tempDir = await Directory.systemTemp.createTemp(
      'hive_widget_single2_',
    );
    Hive.init(tempDir.path);
    registerHiveAdapters();
    await Hive.openBox<GlobalSettings>(HiveBoxes.globalSettings);

    await Hive.box<GlobalSettings>(HiveBoxes.globalSettings).put(
      'SINGLE_VALUE',
      GlobalSettings(
        preferredLocaleSubtag: 'en',
        uploadPresetEnabled: true,
        uploadPresetTitleTemplate: 'Invoice',
        uploadPresetUseCurrentDate: false,
        uploadPresetCorrespondentId: 17,
        uploadPresetDocumentTypeId: 42,
        uploadPresetStoragePathId: 99,
        uploadPresetTagIds: const [7, 8],
        loggedInUserId: '1',
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    await Hive.close();
    await tempDir.delete(recursive: true);
  });
}
