import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/json/json_canonicalizer.dart';

abstract class DocumentListCacheStore {
  Future<PagedSearchResult<DocumentModel>?> read({
    required String userId,
    required DocumentFilter filter,
  });

  Future<void> write({
    required String userId,
    required DocumentFilter filter,
    required PagedSearchResult<DocumentModel> page,
  });
}

class HiveDocumentListCacheStore implements DocumentListCacheStore {
  static const _currentVersion = 2;
  static const _legacyVersionWithoutTimestamp = 1;
  static const _defaultMaxAge = Duration(minutes: 15);

  final Duration maxCacheAge;

  HiveDocumentListCacheStore({this.maxCacheAge = _defaultMaxAge});

  @override
  Future<PagedSearchResult<DocumentModel>?> read({
    required String userId,
    required DocumentFilter filter,
  }) async {
    final box = _cacheBox;
    if (box == null) {
      return null;
    }
    final raw = box.get(_cacheKey(userId, filter));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final version = decoded['version'];
      if (version != _currentVersion &&
          version != _legacyVersionWithoutTimestamp) {
        return null;
      }

      if (version == _currentVersion && !_isFresh(decoded['cachedAt'])) {
        final cacheKey = _cacheKey(userId, filter);
        await _delete(cacheKey);
        return null;
      }

      final pageJson = decoded['page'];
      if (pageJson is! Map<String, dynamic>) {
        return null;
      }
      return PagedSearchResult<DocumentModel>.fromJson(
        pageJson,
        (entry) => DocumentModel.fromJson(entry as Map<String, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write({
    required String userId,
    required DocumentFilter filter,
    required PagedSearchResult<DocumentModel> page,
  }) async {
    final box = _cacheBox;
    if (box == null) {
      return;
    }
    final payload = jsonEncode({
      'version': _currentVersion,
      'cachedAt': DateTime.now().toUtc().toIso8601String(),
      'page': page.toJson((doc) => doc.toJson()),
    });
    await box.put(_cacheKey(userId, filter), payload);
  }

  Box<String>? get _cacheBox {
    if (!Hive.isBoxOpen(HiveBoxes.documentListCache)) {
      return null;
    }
    return Hive.box<String>(HiveBoxes.documentListCache);
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

  bool _isFresh(dynamic cachedAtValue) {
    if (cachedAtValue == null) {
      return false;
    }
    if (cachedAtValue is! String || maxCacheAge == Duration.zero) {
      return false;
    }
    final cachedAt = DateTime.tryParse(cachedAtValue);
    if (cachedAt == null) {
      return false;
    }
    final age = DateTime.now().difference(cachedAt);
    return !age.isNegative && age <= maxCacheAge;
  }

  Future<void> _delete(String cacheKey) async {
    final box = _cacheBox;
    if (box != null) {
      await box.delete(cacheKey);
    }
  }
}
