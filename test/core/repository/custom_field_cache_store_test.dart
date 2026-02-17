import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/repository/custom_field_cache_store.dart';

void main() {
  late Directory hiveDir;
  late Box<String> cacheBox;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('paperless-mobile-hive-');
    Hive.init(hiveDir.path);
    await Hive.openBox<String>(HiveBoxes.customFieldCache);
    cacheBox = Hive.box<String>(HiveBoxes.customFieldCache);
  });

  tearDown(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  test('write/read roundtrip stores custom fields by user', () async {
    final store = HiveCustomFieldCacheStore();
    final fields = [
      CustomFieldModel(
        id: 1,
        name: 'Project',
        dataType: CustomFieldDataType.string,
      ),
      CustomFieldModel(
        id: 2,
        name: 'Amount',
        dataType: CustomFieldDataType.float,
      ),
    ];

    await store.write(userId: 'u1', fields: fields);
    final restored = await store.read(userId: 'u1');

    expect(restored, isNotNull);
    expect(restored!.map((field) => field.id).toList(), [1, 2]);
    expect(restored[1].name, 'Amount');
  });

  test('stale cache entries are invalidated and removed', () async {
    final store = HiveCustomFieldCacheStore(
      maxCacheAge: const Duration(milliseconds: 1),
    );
    await store.write(
      userId: 'u-stale',
      fields: [
        CustomFieldModel(
          id: 10,
          name: 'Legacy',
          dataType: CustomFieldDataType.string,
        ),
      ],
    );

    await Future<void>.delayed(const Duration(milliseconds: 5));
    final restored = await store.read(userId: 'u-stale');

    expect(restored, isNull);
    expect(cacheBox.length, equals(0));
  });

  test('legacy cache payloads without timestamps are still accepted', () async {
    const userId = 'u-legacy';
    await cacheBox.put(
      'custom-field-cache::$userId',
      jsonEncode({
        'version': 1,
        'fields': [
          CustomFieldModel(
            id: 3,
            name: 'Legacy',
            dataType: CustomFieldDataType.string,
          ).toJson(),
        ],
      }),
    );

    final store = HiveCustomFieldCacheStore();
    final restored = await store.read(userId: userId);

    expect(restored, isNotNull);
    expect(restored!.map((field) => field.id).toList(), [3]);
    expect(restored.first.name, 'Legacy');
  });

  test('invalid cachedAt values are invalidated and removed', () async {
    const userId = 'u-invalid-ts';
    await cacheBox.put(
      'custom-field-cache::$userId',
      jsonEncode({'version': 2, 'cachedAt': 'not-a-timestamp', 'fields': []}),
    );

    final store = HiveCustomFieldCacheStore();
    final restored = await store.read(userId: userId);

    expect(restored, isNull);
    expect(cacheBox.length, equals(0));
  });

  test('missing cachedAt values are invalidated and removed', () async {
    const userId = 'u-missing-ts';
    await cacheBox.put(
      'custom-field-cache::$userId',
      jsonEncode({'version': 2, 'fields': []}),
    );

    final store = HiveCustomFieldCacheStore();
    final restored = await store.read(userId: userId);

    expect(restored, isNull);
    expect(cacheBox.length, equals(0));
  });
}
