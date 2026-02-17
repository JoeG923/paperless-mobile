import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/json/json_canonicalizer.dart';
import 'package:paperless_mobile/core/repository/document_list_cache_store.dart';

DocumentModel _document(int id) {
  final now = DateTime(2026, 1, id);
  return DocumentModel(
    id: id,
    title: 'doc-$id',
    documentType: null,
    correspondent: null,
    created: now,
    modified: now,
    added: now,
  );
}

void main() {
  late Directory hiveDir;
  late Box<String> cacheBox;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('paperless-mobile-hive-');
    Hive.init(hiveDir.path);
    await Hive.openBox<String>(HiveBoxes.documentListCache);
    cacheBox = Hive.box<String>(HiveBoxes.documentListCache);
  });

  tearDown(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  test('write/read roundtrip stores first-page snapshots', () async {
    final store = HiveDocumentListCacheStore();
    final page = PagedSearchResult<DocumentModel>(
      count: 1,
      results: [_document(3)],
    );
    const filter = DocumentFilter(query: TextQuery.title('invoice'), page: 5);

    await store.write(userId: 'u1', filter: filter, page: page);
    final restored = await store.read(
      userId: 'u1',
      filter: filter.copyWith(page: 1),
    );

    expect(restored, isNotNull);
    expect(restored!.results.map((doc) => doc.id).toList(), [3]);
  });

  test(
    'cache key canonicalizes equivalent custom field query json expressions',
    () async {
      final store = HiveDocumentListCacheStore();
      final page = PagedSearchResult<DocumentModel>(
        count: 1,
        results: [_document(7)],
      );
      const writeFilter = DocumentFilter(
        customFieldQuery:
            '{"operator":"and","rules":[{"value":1,"field":2},{"b":2,"a":1}]}',
      );
      const readFilter = DocumentFilter(
        customFieldQuery:
            '{ "rules":[{"field":2,"value":1},{"a":1,"b":2}], "operator":"and" }',
      );

      await store.write(userId: 'u2', filter: writeFilter, page: page);
      final restored = await store.read(userId: 'u2', filter: readFilter);

      expect(restored, isNotNull);
      expect(restored!.results.map((doc) => doc.id).toList(), [7]);
    },
  );

  test(
    'cache keys remain distinct for different filters with special characters',
    () async {
      final store = HiveDocumentListCacheStore();
      final firstPage = PagedSearchResult<DocumentModel>(
        count: 1,
        results: [_document(8)],
      );
      final secondPage = PagedSearchResult<DocumentModel>(
        count: 1,
        results: [_document(9)],
      );
      const firstFilter = DocumentFilter(query: TextQuery.title('a&b=c'));
      const secondFilter = DocumentFilter(query: TextQuery.title('a'));

      await store.write(userId: 'u3', filter: firstFilter, page: firstPage);
      await store.write(userId: 'u3', filter: secondFilter, page: secondPage);

      final restoredFirst = await store.read(userId: 'u3', filter: firstFilter);
      final restoredSecond = await store.read(
        userId: 'u3',
        filter: secondFilter,
      );

      expect(restoredFirst?.results.map((doc) => doc.id).toList(), [8]);
      expect(restoredSecond?.results.map((doc) => doc.id).toList(), [9]);
    },
  );

  test('stale cache entries are invalidated and removed', () async {
    final store = HiveDocumentListCacheStore(
      maxCacheAge: const Duration(milliseconds: 1),
    );
    const filter = DocumentFilter(query: TextQuery.title('invoice'), page: 2);
    await store.write(
      userId: 'u4',
      filter: filter,
      page: PagedSearchResult<DocumentModel>(
        count: 1,
        results: [_document(10)],
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 5));
    final restored = await store.read(userId: 'u4', filter: filter);

    expect(restored, isNull);
    expect(cacheBox.length, equals(0));
  });

  test('legacy cache payloads without timestamps are still accepted', () async {
    const filter = DocumentFilter(query: TextQuery.title('legacy'));
    final legacyKey = _cacheKey('u5', filter);
    final legacyPage = PagedSearchResult<DocumentModel>(
      count: 1,
      results: [_document(11)],
    );
    await cacheBox.put(
      legacyKey,
      jsonEncode({
        'version': 1,
        'page': legacyPage.toJson((doc) => doc.toJson()),
      }),
    );

    final store = HiveDocumentListCacheStore();
    final restored = await store.read(userId: 'u5', filter: filter);

    expect(restored, isNotNull);
    expect(restored!.results.map((doc) => doc.id).toList(), [11]);
  });

  test(
    'versioned cache payloads with missing cachedAt are invalidated',
    () async {
      const filter = DocumentFilter(query: TextQuery.title('missing-ts'));
      final staleKey = _cacheKey('u6', filter);
      final stalePayload = PagedSearchResult<DocumentModel>(
        count: 1,
        results: [_document(12)],
      );
      await cacheBox.put(
        staleKey,
        jsonEncode({
          'version': 2,
          'page': stalePayload.toJson((doc) => doc.toJson()),
        }),
      );

      final store = HiveDocumentListCacheStore();
      final restored = await store.read(userId: 'u6', filter: filter);

      expect(restored, isNull);
      expect(cacheBox.length, equals(0));
    },
  );
}

String _cacheKey(String userId, DocumentFilter filter) {
  final normalizedFilter = filter.copyWith(
    page: 1,
    customFieldQuery: () => canonicalizeJsonString(filter.customFieldQuery),
  );
  final params = normalizedFilter.toQueryParameters().entries.toList()
    ..sort((a, b) {
      final keyCompare = a.key.compareTo(b.key);
      if (keyCompare != 0) {
        return keyCompare;
      }
      return '${a.value}'.compareTo('${b.value}');
    });
  final encodedParams = params.map(
    (entry) =>
        '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(_normalizedParamValue(entry.key, entry.value))}',
  );
  return '$userId::${encodedParams.join('&')}';
}

String _normalizedParamValue(String key, Object? value) {
  final normalized = '$value';
  if (key == 'custom_field_query') {
    return canonicalizeJsonString(normalized) ?? normalized;
  }
  return normalized;
}
