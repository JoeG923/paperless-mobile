import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/repository/custom_field_cache_store.dart';
import 'package:paperless_mobile/features/logging/data/logger.dart';

class CustomFieldRepository extends ChangeNotifier {
  final CustomFieldsApi _api;
  final String? _userId;
  final CustomFieldCacheStore _cacheStore;

  Map<int, CustomFieldModel> customFields = {};

  CustomFieldRepository(
    this._api, {
    String? userId,
    CustomFieldCacheStore? cacheStore,
  }) : _userId = userId,
       _cacheStore = cacheStore ?? HiveCustomFieldCacheStore();

  Future<void> initialize() async {
    await _restoreCache();
    try {
      await findAll();
    } catch (error, stackTrace) {
      logger.fw(
        'Failed to refresh custom fields, keeping cached values.',
        className: runtimeType.toString(),
        methodName: 'initialize',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Iterable<CustomFieldModel>> findAll() async {
    final fields = await _api.getCustomFields();
    final nextFields = {
      for (final field in fields)
        if (field.id != null) field.id!: field,
    };
    if (_materiallySameFields(nextFields)) {
      return fields;
    }
    customFields = nextFields;
    await _persistCache();
    notifyListeners();
    return fields;
  }

  Future<CustomFieldModel?> find(int id) async {
    final field = await _api.getCustomField(id);
    if (field != null && field.id != null) {
      customFields = {...customFields, field.id!: field};
      await _persistCache();
      notifyListeners();
    }
    return field;
  }

  Future<void> _restoreCache() async {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    final cachedFields = await _cacheStore.read(userId: userId);
    if (cachedFields == null || cachedFields.isEmpty) {
      return;
    }
    customFields = {
      for (final field in cachedFields)
        if (field.id != null) field.id!: field,
    };
    notifyListeners();
  }

  Future<void> _persistCache() async {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    await _cacheStore.write(
      userId: userId,
      fields: customFields.values.toList(growable: false),
    );
  }

  bool _materiallySameFields(Map<int, CustomFieldModel> nextFields) {
    if (identical(customFields, nextFields)) {
      return true;
    }
    if (customFields.length != nextFields.length) {
      return false;
    }
    for (final entry in nextFields.entries) {
      final existing = customFields[entry.key];
      if (existing == null) {
        return false;
      }
      if (!_materiallySameField(existing, entry.value)) {
        return false;
      }
    }
    return true;
  }

  bool _materiallySameField(CustomFieldModel left, CustomFieldModel right) =>
      const DeepCollectionEquality().equals(left.toJson(), right.toJson());
}
