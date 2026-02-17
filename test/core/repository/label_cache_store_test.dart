import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/repository/label_cache_store.dart';

void main() {
  late Directory hiveDir;
  late Box<String> cacheBox;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('paperless-mobile-hive-');
    Hive.init(hiveDir.path);
    await Hive.openBox<String>(HiveBoxes.labelCache);
    cacheBox = Hive.box<String>(HiveBoxes.labelCache);
  });

  tearDown(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  test('write/read roundtrip stores label catalogs per user', () async {
    final store = HiveLabelCacheStore();
    final snapshot = LabelCacheSnapshot(
      correspondents: const [Correspondent(id: 1, name: 'Acme Corp')],
      documentTypes: const [DocumentType(id: 2, name: 'Invoice')],
      storagePaths: const [
        StoragePath(id: 3, name: 'Cabinet', path: '/cabinet'),
      ],
      tags: const [Tag(id: 4, name: 'Urgent')],
    );

    await store.write(userId: 'user-a', snapshot: snapshot);
    final restored = await store.read(userId: 'user-a');

    expect(restored, isNotNull);
    expect(restored!.correspondents.map((e) => e.id).toList(), [1]);
    expect(restored.documentTypes.map((e) => e.id).toList(), [2]);
    expect(restored.storagePaths.map((e) => e.id).toList(), [3]);
    expect(restored.tags.map((e) => e.id).toList(), [4]);
  });

  test('stale cache entries are invalidated and removed', () async {
    final store = HiveLabelCacheStore(
      maxCacheAge: const Duration(milliseconds: 1),
    );
    final snapshot = LabelCacheSnapshot(
      correspondents: const [Correspondent(id: 1, name: 'Acme Corp')],
      documentTypes: const [DocumentType(id: 2, name: 'Invoice')],
      storagePaths: const [
        StoragePath(id: 3, name: 'Cabinet', path: '/cabinet'),
      ],
      tags: const [Tag(id: 4, name: 'Urgent')],
    );

    await store.write(userId: 'user-stale', snapshot: snapshot);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final restored = await store.read(userId: 'user-stale');

    expect(restored, isNull);
    expect(cacheBox.length, equals(0));
  });

  test('legacy cache payloads without timestamps are still accepted', () async {
    const userId = 'user-legacy';
    await cacheBox.put(
      _cacheKey(userId),
      jsonEncode({
        'version': 1,
        'correspondents': [
          const Correspondent(id: 11, name: 'Legacy').toJson(),
        ],
        'documentTypes': [
          const DocumentType(id: 22, name: 'LegacyType').toJson(),
        ],
        'storagePaths': [
          const StoragePath(
            id: 33,
            name: 'LegacyPath',
            path: '/legacy',
          ).toJson(),
        ],
        'tags': [const Tag(id: 44, name: 'LegacyTag').toJson()],
      }),
    );

    final store = HiveLabelCacheStore();
    final restored = await store.read(userId: userId);

    expect(restored, isNotNull);
    expect(restored!.correspondents.map((item) => item.id).toList(), [11]);
    expect(restored.documentTypes.map((item) => item.id).toList(), [22]);
    expect(restored.storagePaths.map((item) => item.id).toList(), [33]);
    expect(restored.tags.map((item) => item.id).toList(), [44]);
  });

  test('invalid cachedAt values are invalidated and removed', () async {
    const userId = 'user-invalid-ts';
    await cacheBox.put(
      _cacheKey(userId),
      jsonEncode({
        'version': 2,
        'cachedAt': 'not-a-timestamp',
        'correspondents': <Map<String, dynamic>>[],
        'documentTypes': <Map<String, dynamic>>[],
        'storagePaths': <Map<String, dynamic>>[],
        'tags': <Map<String, dynamic>>[],
      }),
    );

    final store = HiveLabelCacheStore();
    final restored = await store.read(userId: userId);

    expect(restored, isNull);
    expect(cacheBox.length, equals(0));
  });

  test('missing cachedAt values are invalidated and removed', () async {
    const userId = 'user-missing-ts';
    await cacheBox.put(
      _cacheKey(userId),
      jsonEncode({
        'version': 2,
        'correspondents': <Map<String, dynamic>>[],
        'documentTypes': <Map<String, dynamic>>[],
        'storagePaths': <Map<String, dynamic>>[],
        'tags': <Map<String, dynamic>>[],
      }),
    );

    final store = HiveLabelCacheStore();
    final restored = await store.read(userId: userId);

    expect(restored, isNull);
    expect(cacheBox.length, equals(0));
  });
}

String _cacheKey(String userId) => 'label-cache::$userId';
