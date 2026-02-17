import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/core/repository/document_list_cache_store.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/similar_documents/cubit/similar_documents_cubit.dart';

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
    created: now,
    modified: now,
    added: now,
  );
}

void main() {
  test('initialize restores cached similar documents while offline', () async {
    final cache = _InMemoryCacheStore()
      ..cachedPage = PagedSearchResult<DocumentModel>(
        count: 1,
        results: [_document(1)],
      );
    final api = _FakeDocumentsApi(
      response: PagedSearchResult<DocumentModel>(
        count: 1,
        results: [_document(2)],
      ),
    );
    final notifier = DocumentChangedNotifier();
    final cubit = SimilarDocumentsCubit(
      api,
      notifier,
      ConnectivityStatusServiceMock(false),
      documentId: 42,
      userId: 'u1',
      documentListCacheStore: cache,
    );

    await cubit.initialize();

    expect(api.findAllCalls, 0);
    expect(cache.readCalls, 1);
    expect(cache.writeCalls, 1);
    expect(cubit.state.documents.map((doc) => doc.id).toList(), [1]);

    await cubit.close();
    notifier.close();
  });

  test('initialize fetches online and persists similar documents', () async {
    final cache = _InMemoryCacheStore();
    final api = _FakeDocumentsApi(
      response: PagedSearchResult<DocumentModel>(
        count: 1,
        results: [_document(3)],
      ),
    );
    final notifier = DocumentChangedNotifier();
    final cubit = SimilarDocumentsCubit(
      api,
      notifier,
      ConnectivityStatusServiceMock(true),
      documentId: 42,
      userId: 'u2',
      documentListCacheStore: cache,
    );

    await cubit.initialize();

    expect(api.findAllCalls, 1);
    expect(cache.readCalls, 1);
    expect(cache.writeCalls, 1);
    expect(cache.cachedPage?.results.map((doc) => doc.id).toList(), [3]);

    await cubit.close();
    notifier.close();
  });
}
