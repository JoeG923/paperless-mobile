import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_app_state.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/core/repository/document_list_cache_store.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/documents/cubit/documents_cubit.dart';

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

class _InMemoryCacheStore implements DocumentListCacheStore {
  PagedSearchResult<DocumentModel>? cachedPage;
  int readCalls = 0;
  int writeCalls = 0;
  String? lastUserId;
  DocumentFilter? lastFilter;

  @override
  Future<PagedSearchResult<DocumentModel>?> read({
    required String userId,
    required DocumentFilter filter,
  }) async {
    readCalls += 1;
    lastUserId = userId;
    lastFilter = filter;
    return cachedPage;
  }

  @override
  Future<void> write({
    required String userId,
    required DocumentFilter filter,
    required PagedSearchResult<DocumentModel> page,
  }) async {
    writeCalls += 1;
    lastUserId = userId;
    lastFilter = filter;
    cachedPage = page;
  }
}

class _InMemoryLocalUserAppState extends LocalUserAppState {
  _InMemoryLocalUserAppState({required super.userId});

  @override
  Future<void> save() async {}
}

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
  test('initialize hydrates cached documents while offline', () async {
    final cachedPage = PagedSearchResult<DocumentModel>(
      count: 1,
      results: [_document(42)],
    );
    final api = _FakeDocumentsApi(
      response: const PagedSearchResult(count: 0, results: []),
    );
    final cache = _InMemoryCacheStore()..cachedPage = cachedPage;
    final notifier = DocumentChangedNotifier();
    final cubit = DocumentsCubit(
      api,
      notifier,
      _InMemoryLocalUserAppState(userId: 'user-1'),
      ConnectivityStatusServiceMock(false),
      documentListCacheStore: cache,
    );

    await cubit.initialize();

    expect(api.findAllCalls, 0);
    expect(cubit.state.documents.map((d) => d.id).toList(), [42]);
    expect(cache.readCalls, 1);
    expect(cache.writeCalls, 1);

    await cubit.close();
    notifier.close();
  });

  test('initialize fetches online and persists first page snapshot', () async {
    final networkPage = PagedSearchResult<DocumentModel>(
      count: 1,
      results: [_document(7)],
    );
    final api = _FakeDocumentsApi(response: networkPage);
    final cache = _InMemoryCacheStore();
    final notifier = DocumentChangedNotifier();
    final cubit = DocumentsCubit(
      api,
      notifier,
      _InMemoryLocalUserAppState(userId: 'user-2'),
      ConnectivityStatusServiceMock(true),
      documentListCacheStore: cache,
    );

    await cubit.initialize();

    expect(api.findAllCalls, 1);
    expect(cache.readCalls, 1);
    expect(cache.writeCalls, 1);
    expect(cache.cachedPage?.results.map((d) => d.id).toList(), [7]);

    await cubit.close();
    notifier.close();
  });
}
