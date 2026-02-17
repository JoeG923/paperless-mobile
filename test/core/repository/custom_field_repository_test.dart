import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/repository/custom_field_cache_store.dart';
import 'package:paperless_mobile/core/repository/custom_field_repository.dart';
import 'package:paperless_mobile/features/logging/data/logger.dart'
    as app_logger;

class _FakeCustomFieldsApi implements CustomFieldsApi {
  List<CustomFieldModel> fields;
  final bool throwOnGetCustomFields;

  _FakeCustomFieldsApi(this.fields, {this.throwOnGetCustomFields = false});

  @override
  Future<CustomFieldModel> createCustomField(
    CustomFieldModel customField,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<int> deleteCustomField(CustomFieldModel customField) async {
    throw UnimplementedError();
  }

  @override
  Future<CustomFieldModel?> getCustomField(int id) async {
    return fields.where((field) => field.id == id).firstOrNull;
  }

  @override
  Future<List<CustomFieldModel>> getCustomFields() async {
    if (throwOnGetCustomFields) {
      throw Exception('offline');
    }
    return fields;
  }
}

class _FakeCustomFieldCacheStore implements CustomFieldCacheStore {
  List<CustomFieldModel>? snapshot;
  List<CustomFieldModel>? lastWrittenFields;
  String? lastReadUserId;
  String? lastWriteUserId;
  int writeCount = 0;

  @override
  Future<List<CustomFieldModel>?> read({required String userId}) async {
    lastReadUserId = userId;
    return snapshot;
  }

  @override
  Future<void> write({
    required String userId,
    required List<CustomFieldModel> fields,
  }) async {
    writeCount += 1;
    lastWriteUserId = userId;
    lastWrittenFields = List<CustomFieldModel>.from(fields);
  }
}

void main() {
  setUp(() {
    app_logger.logger = Logger(level: Level.off);
  });

  test('initialize refreshes fields and persists cache', () async {
    final cacheStore = _FakeCustomFieldCacheStore();
    final repository = CustomFieldRepository(
      _FakeCustomFieldsApi([
        CustomFieldModel(
          id: 1,
          name: 'Invoice',
          dataType: CustomFieldDataType.string,
        ),
        CustomFieldModel(
          id: 2,
          name: 'Amount',
          dataType: CustomFieldDataType.float,
        ),
      ]),
      userId: 'u1',
      cacheStore: cacheStore,
    );

    await repository.initialize();

    expect(repository.customFields.keys.toSet(), {1, 2});
    expect(repository.customFields[2]?.name, 'Amount');
    expect(cacheStore.lastWriteUserId, 'u1');
    expect(cacheStore.writeCount, 1);
    expect(cacheStore.lastWrittenFields?.map((field) => field.id).toList(), [
      1,
      2,
    ]);
  });

  test(
    'findAll avoids cache writes and notifications when data is unchanged',
    () async {
      final cacheStore = _FakeCustomFieldCacheStore();
      final api = _FakeCustomFieldsApi([
        CustomFieldModel(
          id: 1,
          name: 'Invoice',
          dataType: CustomFieldDataType.string,
        ),
        CustomFieldModel(
          id: 2,
          name: 'Amount',
          dataType: CustomFieldDataType.float,
        ),
      ]);
      final repository = CustomFieldRepository(
        api,
        userId: 'u3',
        cacheStore: cacheStore,
      );
      var notificationCount = 0;
      repository.addListener(() {
        notificationCount += 1;
      });

      await repository.findAll();
      api.fields = [
        CustomFieldModel(
          id: 2,
          name: 'Amount',
          dataType: CustomFieldDataType.float,
        ),
        CustomFieldModel(
          id: 1,
          name: 'Invoice',
          dataType: CustomFieldDataType.string,
        ),
      ];
      await repository.findAll();

      expect(cacheStore.writeCount, 1);
      expect(notificationCount, 1);
      expect(repository.customFields.keys.toSet(), {1, 2});
    },
  );

  test('findAll persists and notifies when fetched data changes', () async {
    final cacheStore = _FakeCustomFieldCacheStore();
    final api = _FakeCustomFieldsApi([
      CustomFieldModel(
        id: 1,
        name: 'Invoice',
        dataType: CustomFieldDataType.string,
      ),
    ]);
    final repository = CustomFieldRepository(
      api,
      userId: 'u4',
      cacheStore: cacheStore,
    );
    var notificationCount = 0;
    repository.addListener(() {
      notificationCount += 1;
    });

    await repository.findAll();
    api.fields = [
      CustomFieldModel(
        id: 1,
        name: 'Invoice Updated',
        dataType: CustomFieldDataType.string,
      ),
    ];
    await repository.findAll();

    expect(cacheStore.writeCount, 2);
    expect(notificationCount, 2);
    expect(repository.customFields[1]?.name, 'Invoice Updated');
  });

  test('initialize restores cached fields when refresh fails', () async {
    final cacheStore = _FakeCustomFieldCacheStore()
      ..snapshot = [
        CustomFieldModel(
          id: 7,
          name: 'Cached Field',
          dataType: CustomFieldDataType.string,
        ),
      ];
    final repository = CustomFieldRepository(
      _FakeCustomFieldsApi([], throwOnGetCustomFields: true),
      userId: 'u2',
      cacheStore: cacheStore,
    );
    var notificationCount = 0;
    repository.addListener(() {
      notificationCount += 1;
    });

    await repository.initialize();

    expect(cacheStore.lastReadUserId, 'u2');
    expect(cacheStore.writeCount, 0);
    expect(notificationCount, 1);
    expect(repository.customFields.keys.toSet(), {7});
    expect(repository.customFields[7]?.name, 'Cached Field');
  });
}
