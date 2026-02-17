import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';

void main() {
  test('hive put with preset settings', () async {
    final tempDir = await Directory.systemTemp.createTemp('hive_put_repro_');
    Hive.init(tempDir.path);
    registerHiveAdapters();
    final box = await Hive.openBox<GlobalSettings>(HiveBoxes.globalSettings);

    final initial = GlobalSettings(
      preferredLocaleSubtag: 'en',
      loggedInUserId: '1',
    );
    await box.put('SINGLE_VALUE', initial);
    final updated = GlobalSettings(
      preferredLocaleSubtag: 'en',
      uploadPresetEnabled: true,
      uploadPresetTitleTemplate: 'Invoice',
      uploadPresetUseCurrentDate: false,
      uploadPresetCorrespondentId: 17,
      uploadPresetDocumentTypeId: 42,
      uploadPresetStoragePathId: 99,
      uploadPresetTagIds: const [7, 8],
      loggedInUserId: '1',
    );

    await box.put('SINGLE_VALUE', updated);

    final readBack = box.get('SINGLE_VALUE');
    expect(readBack?.uploadPresetEnabled, isTrue);
    await box.close();
    await tempDir.delete(recursive: true);
  });
}
