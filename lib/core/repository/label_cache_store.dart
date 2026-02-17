import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';

class LabelCacheSnapshot {
  final List<Correspondent> correspondents;
  final List<DocumentType> documentTypes;
  final List<StoragePath> storagePaths;
  final List<Tag> tags;

  const LabelCacheSnapshot({
    required this.correspondents,
    required this.documentTypes,
    required this.storagePaths,
    required this.tags,
  });
}

abstract class LabelCacheStore {
  Future<LabelCacheSnapshot?> read({required String userId});

  Future<void> write({
    required String userId,
    required LabelCacheSnapshot snapshot,
  });
}

class HiveLabelCacheStore implements LabelCacheStore {
  static const _currentVersion = 2;
  static const _legacyVersion = 1;
  static const _defaultMaxAge = Duration(minutes: 15);

  final Duration maxCacheAge;

  HiveLabelCacheStore({this.maxCacheAge = _defaultMaxAge});

  @override
  Future<LabelCacheSnapshot?> read({required String userId}) async {
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
      if (version != _currentVersion && version != _legacyVersion) {
        return null;
      }
      if (version == _currentVersion && !_isFresh(decoded['cachedAt'])) {
        await _delete(_cacheKey(userId));
        return null;
      }

      return LabelCacheSnapshot(
        correspondents: _parseList(
          decoded['correspondents'],
          (json) => Correspondent.fromJson(json),
        ),
        documentTypes: _parseList(
          decoded['documentTypes'],
          (json) => DocumentType.fromJson(json),
        ),
        storagePaths: _parseList(
          decoded['storagePaths'],
          (json) => StoragePath.fromJson(json),
        ),
        tags: _parseList(decoded['tags'], (json) => Tag.fromJson(json)),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write({
    required String userId,
    required LabelCacheSnapshot snapshot,
  }) async {
    final box = _cacheBox;
    if (box == null) {
      return;
    }
    final payload = jsonEncode({
      'version': _currentVersion,
      'cachedAt': DateTime.now().toUtc().toIso8601String(),
      'correspondents': snapshot.correspondents.map((e) => e.toJson()).toList(),
      'documentTypes': snapshot.documentTypes.map((e) => e.toJson()).toList(),
      'storagePaths': snapshot.storagePaths.map((e) => e.toJson()).toList(),
      'tags': snapshot.tags.map((e) => e.toJson()).toList(),
    });
    await box.put(_cacheKey(userId), payload);
  }

  Box<String>? get _cacheBox {
    if (!Hive.isBoxOpen(HiveBoxes.labelCache)) {
      return null;
    }
    return Hive.box<String>(HiveBoxes.labelCache);
  }

  String _cacheKey(String userId) => 'label-cache::$userId';

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

  List<T> _parseList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw is! List) {
      return const [];
    }
    final result = <T>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        result.add(fromJson(entry));
      } else if (entry is Map) {
        result.add(
          fromJson(
            Map<String, dynamic>.from(
              entry.map((key, value) => MapEntry(key.toString(), value)),
            ),
          ),
        );
      }
    }
    return result;
  }
}
