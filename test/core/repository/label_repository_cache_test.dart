import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/repository/label_cache_store.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/features/logging/data/logger.dart'
    as app_logger;

class _FakeLabelCacheStore implements LabelCacheStore {
  LabelCacheSnapshot? snapshot;
  LabelCacheSnapshot? lastWrittenSnapshot;
  String? lastReadUserId;
  String? lastWriteUserId;
  int writeCount = 0;

  @override
  Future<LabelCacheSnapshot?> read({required String userId}) async {
    lastReadUserId = userId;
    return snapshot;
  }

  @override
  Future<void> write({
    required String userId,
    required LabelCacheSnapshot snapshot,
  }) async {
    lastWriteUserId = userId;
    lastWrittenSnapshot = snapshot;
    writeCount++;
  }
}

class _FakeLabelsApi implements PaperlessLabelsApi {
  final List<Tag> tags;
  final bool throwOnGetTags;

  _FakeLabelsApi({this.tags = const [], this.throwOnGetTags = false});

  @override
  Future<Tag?> getTag(int id) async {
    for (final tag in tags) {
      if (tag.id == id) {
        return tag;
      }
    }
    return null;
  }

  @override
  Future<List<Tag>> getTags([Iterable<int>? ids]) async {
    if (throwOnGetTags) {
      throw Exception('offline');
    }
    if (ids == null || ids.isEmpty) {
      return tags;
    }
    return tags.where((tag) => ids.contains(tag.id)).toList();
  }

  @override
  Future<Tag> saveTag(Tag tag) async => tag;

  @override
  Future<Tag> updateTag(Tag tag) async => tag;

  @override
  Future<int> deleteTag(Tag tag) async => tag.id ?? -1;

  @override
  Future<Correspondent?> getCorrespondent(int id) async => null;

  @override
  Future<List<Correspondent>> getCorrespondents([Iterable<int>? ids]) async =>
      const [];

  @override
  Future<Correspondent> saveCorrespondent(Correspondent correspondent) async =>
      correspondent;

  @override
  Future<Correspondent> updateCorrespondent(
    Correspondent correspondent,
  ) async => correspondent;

  @override
  Future<int> deleteCorrespondent(Correspondent correspondent) async =>
      correspondent.id ?? -1;

  @override
  Future<DocumentType?> getDocumentType(int id) async => null;

  @override
  Future<List<DocumentType>> getDocumentTypes([Iterable<int>? ids]) async =>
      const [];

  @override
  Future<DocumentType> saveDocumentType(DocumentType type) async => type;

  @override
  Future<DocumentType> updateDocumentType(DocumentType documentType) async =>
      documentType;

  @override
  Future<int> deleteDocumentType(DocumentType documentType) async =>
      documentType.id ?? -1;

  @override
  Future<StoragePath?> getStoragePath(int id) async => null;

  @override
  Future<List<StoragePath>> getStoragePaths([Iterable<int>? ids]) async =>
      const [];

  @override
  Future<StoragePath> saveStoragePath(StoragePath path) async => path;

  @override
  Future<StoragePath> updateStoragePath(StoragePath path) async => path;

  @override
  Future<int> deleteStoragePath(StoragePath path) async => path.id ?? -1;
}

void main() {
  setUp(() {
    app_logger.logger = Logger(level: Level.off);
  });

  test('initialize restores cached tags when remote refresh fails', () async {
    final cacheStore = _FakeLabelCacheStore()
      ..snapshot = const LabelCacheSnapshot(
        correspondents: [],
        documentTypes: [],
        storagePaths: [],
        tags: [Tag(id: 7, name: 'Cached')],
      );
    final repository = LabelRepository(
      _FakeLabelsApi(throwOnGetTags: true),
      userId: 'u1',
      cacheStore: cacheStore,
    );

    await repository.initialize(
      loadCorrespondents: false,
      loadDocumentTypes: false,
      loadStoragePaths: false,
      loadTags: true,
    );

    expect(cacheStore.lastReadUserId, 'u1');
    expect(repository.tags.keys.toSet(), {7});
    expect(repository.tags[7]?.name, 'Cached');
  });

  test('findAllTags persists refreshed tags to cache', () async {
    final cacheStore = _FakeLabelCacheStore();
    final repository = LabelRepository(
      _FakeLabelsApi(tags: const [Tag(id: 3, name: 'Remote')]),
      userId: 'u2',
      cacheStore: cacheStore,
    );

    await repository.findAllTags();

    expect(repository.tags.keys.toSet(), {3});
    expect(cacheStore.lastWriteUserId, 'u2');
    expect(cacheStore.lastWrittenSnapshot, isNotNull);
    expect(cacheStore.lastWrittenSnapshot!.tags.map((tag) => tag.id).toList(), [
      3,
    ]);
  });

  test(
    'initialize batches writes and notifications into a single flush',
    () async {
      final cacheStore = _FakeLabelCacheStore();
      final repository = LabelRepository(
        _FakeLabelsApi(tags: const [Tag(id: 4, name: 'Inbox')]),
        userId: 'u3',
        cacheStore: cacheStore,
      );
      var notifications = 0;
      repository.addListener(() => notifications++);

      await repository.initialize(
        loadCorrespondents: true,
        loadDocumentTypes: true,
        loadStoragePaths: true,
        loadTags: true,
      );

      expect(cacheStore.writeCount, 1);
      expect(notifications, 1);
      expect(repository.tags.keys.toSet(), {4});
    },
  );
}
