import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_app_state.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/core/repository/document_list_cache_store.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/saved_view_details/cubit/saved_view_details_cubit.dart';

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

Future<void> _waitUntil(bool Function() predicate) async {
  for (var i = 0; i < 50; i++) {
    if (predicate()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('timed out waiting for expected state');
}

void main() {
  final savedView = SavedView(
    id: 7,
    name: 'Saved',
    showOnDashboard: false,
    showInSidebar: false,
    sortField: SortField.created,
    sortReverse: false,
    filterRules: [],
  );

  test('constructor restores cached page while offline', () async {
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
    final cubit = SavedViewDetailsCubit(
      api,
      notifier,
      _InMemoryLocalUserAppState(userId: 'u1'),
      ConnectivityStatusServiceMock(false),
      savedView: savedView,
      documentListCacheStore: cache,
    );

    await _waitUntil(() => cache.writeCalls > 0);

    expect(api.findAllCalls, 0);
    expect(cache.readCalls, 1);
    expect(cache.writeCalls, 1);
    expect(cubit.state.documents.map((doc) => doc.id).toList(), [1]);

    await cubit.close();
    notifier.close();
  });

  test('constructor fetches online and persists first page snapshot', () async {
    final cache = _InMemoryCacheStore();
    final api = _FakeDocumentsApi(
      response: PagedSearchResult<DocumentModel>(
        count: 1,
        results: [_document(3)],
      ),
    );
    final notifier = DocumentChangedNotifier();
    final cubit = SavedViewDetailsCubit(
      api,
      notifier,
      _InMemoryLocalUserAppState(userId: 'u2'),
      ConnectivityStatusServiceMock(true),
      savedView: savedView,
      documentListCacheStore: cache,
    );

    await _waitUntil(() => cache.writeCalls > 0);

    expect(api.findAllCalls, 1);
    expect(cache.readCalls, 1);
    expect(cache.writeCalls, 1);
    expect(cache.cachedPage?.results.map((doc) => doc.id).toList(), [3]);

    await cubit.close();
    notifier.close();
  });
}
