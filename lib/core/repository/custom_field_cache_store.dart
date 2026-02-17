import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';

abstract class CustomFieldCacheStore {
  Future<List<CustomFieldModel>?> read({required String userId});

  Future<void> write({
    required String userId,
    required List<CustomFieldModel> fields,
  });
}

class HiveCustomFieldCacheStore implements CustomFieldCacheStore {
  static const _currentVersion = 2;
  static const _legacyVersionWithoutTimestamp = 1;
  static const _defaultMaxAge = Duration(minutes: 15);

  final Duration maxCacheAge;

  HiveCustomFieldCacheStore({this.maxCacheAge = _defaultMaxAge});

  @override
  Future<List<CustomFieldModel>?> read({required String userId}) async {
    final box = _cacheBox;
    if (box == null) {
      return null;
    }
    final raw = box.get(_cacheKey(userId));
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
        await _delete(_cacheKey(userId));
        return null;
      }
      final rawFields = decoded['fields'];
      if (rawFields is! List) {
        return null;
      }

      return rawFields
          .whereType<Map>()
          .map(
            (entry) => CustomFieldModel.fromJson(
              Map<String, dynamic>.from(
                entry.map((key, value) => MapEntry(key.toString(), value)),
              ),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write({
    required String userId,
    required List<CustomFieldModel> fields,
  }) async {
    final box = _cacheBox;
    if (box == null) {
      return;
    }
    final payload = jsonEncode({
      'version': _currentVersion,
      'cachedAt': DateTime.now().toUtc().toIso8601String(),
      'fields': fields.map((field) => field.toJson()).toList(growable: false),
    });
    await box.put(_cacheKey(userId), payload);
  }

  Box<String>? get _cacheBox {
    if (!Hive.isBoxOpen(HiveBoxes.customFieldCache)) {
      return null;
    }
    return Hive.box<String>(HiveBoxes.customFieldCache);
  }

  String _cacheKey(String userId) => 'custom-field-cache::$userId';

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
