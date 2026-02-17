import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/core/repository/document_list_cache_store.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/inbox/cubit/inbox_cubit.dart';

class _FakeDocumentsApi extends Fake implements PaperlessDocumentsApi {
  int findAllCalls = 0;
  PagedSearchResult<DocumentModel> response;

  _FakeDocumentsApi({required this.response});

  @override
  Future<PagedSearchResult<DocumentModel>> findAll(
    DocumentFilter filter,
  ) async {
    findAllCalls += 1;
    return response;
  }
}

class _FakeLabelsApi extends Fake implements PaperlessLabelsApi {
  @override
  Future<List<Tag>> getTags([Iterable<int>? ids]) async {
    return const [Tag(id: 99, name: 'Inbox', isInboxTag: true)];
  }
}

class _FakeServerStatsApi extends Fake implements PaperlessServerStatsApi {}

class _FakeLabelRepository extends LabelRepository {
  _FakeLabelRepository() : super(_FakeLabelsApi());

  @override
  Future<Iterable<Tag>> findAllTags([Iterable<int>? ids]) async {
    return const [Tag(id: 99, name: 'Inbox', isInboxTag: true)];
  }
}

class _InMemoryHydratedStorage implements Storage {
  final Map<String, dynamic> _state = {};

  @override
  dynamic read(String key) => _state[key];

  @override
  Future<void> write(String key, dynamic value) async {
    _state[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _state.remove(key);
  }

  @override
  Future<void> clear() async {
    _state.clear();
  }

  @override
  Future<void> close() async {}
}

class _InMemoryCacheStore implements DocumentListCacheStore {
  PagedSearchResult<DocumentModel>? cachedPage;
  int readCalls = 0;
  int writeCalls = 0;

  @override
  Future<PagedSearchResult<DocumentModel>?> read({
    required String userId,
    required DocumentFilter filter,
  }) async {
    readCalls += 1;
    return cachedPage;
  }

  @override
  Future<void> write({
    required String userId,
    required DocumentFilter filter,
    required PagedSearchResult<DocumentModel> page,
  }) async {
    writeCalls += 1;
    cachedPage = page;
  }
}

DocumentModel _document(int id) {
  final now = DateTime(2026, 1, id);
  return DocumentModel(
    id: id,
    title: 'doc-$id',
    documentType: null,
    correspondent: null,
    tags: const [99],
    created: now,
    modified: now,
    added: now,
  );
}

void main() {
  setUp(() {
    HydratedBloc.storage = _InMemoryHydratedStorage();
  });

  test('loadInbox restores cached results while offline', () async {
    final cache = _InMemoryCacheStore()
      ..cachedPage = PagedSearchResult<DocumentModel>(
        count: 1,
        results: [_document(1)],
      );
    final docsApi = _FakeDocumentsApi(
      response: PagedSearchResult<DocumentModel>(
        count: 1,
        results: [_document(2)],
      ),
    );
    final notifier = DocumentChangedNotifier();
    final cubit = InboxCubit(
      docsApi,
      _FakeServerStatsApi(),
      _FakeLabelRepository(),
      notifier,
      ConnectivityStatusServiceMock(false),
      userId: 'u1',
      documentListCacheStore: cache,
    );

    await cubit.loadInbox();

    expect(docsApi.findAllCalls, 0);
    expect(cache.readCalls, 1);
    expect(cache.writeCalls, 1);
    expect(cubit.state.documents.map((doc) => doc.id).toList(), [1]);

    await cubit.close();
    notifier.close();
  });

  test('loadInbox fetches online and persists first page snapshot', () async {
    final cache = _InMemoryCacheStore();
    final docsApi = _FakeDocumentsApi(
      response: PagedSearchResult<DocumentModel>(
        count: 1,
        results: [_document(3)],
      ),
    );
    final notifier = DocumentChangedNotifier();
    final cubit = InboxCubit(
      docsApi,
      _FakeServerStatsApi(),
      _FakeLabelRepository(),
      notifier,
      ConnectivityStatusServiceMock(true),
      userId: 'u2',
      documentListCacheStore: cache,
    );

    await cubit.loadInbox();

    expect(docsApi.findAllCalls, 1);
    expect(cache.readCalls, 1);
    expect(cache.writeCalls, 1);
    expect(cache.cachedPage?.results.map((doc) => doc.id).toList(), [3]);

    await cubit.close();
    notifier.close();
  });
}
