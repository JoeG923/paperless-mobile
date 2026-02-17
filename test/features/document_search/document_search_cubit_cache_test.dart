import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_app_state.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/core/repository/document_list_cache_store.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/document_search/cubit/document_search_cubit.dart';

class _FakeDocumentsApi extends Fake implements PaperlessDocumentsApi {
  int findAllCalls = 0;
  int autocompleteCalls = 0;
  PagedSearchResult<DocumentModel> response;

  _FakeDocumentsApi({required this.response});

  @override
  Future<PagedSearchResult<DocumentModel>> findAll(
    DocumentFilter filter,
  ) async {
    findAllCalls += 1;
    return response;
  }

  @override
  Future<List<String>> autocomplete(String query, [int limit = 10]) async {
    autocompleteCalls += 1;
    return ['$query-1', '$query-2'];
  }
}

class _SequencedDocumentsApi extends _FakeDocumentsApi {
  final List<Completer<PagedSearchResult<DocumentModel>>> _responses;
  int _nextResponseIndex = 0;

  _SequencedDocumentsApi({
    required List<Completer<PagedSearchResult<DocumentModel>>> responses,
  }) : _responses = responses,
       super(response: const PagedSearchResult(count: 0, results: []));

  @override
  Future<PagedSearchResult<DocumentModel>> findAll(
    DocumentFilter filter,
  ) async {
    findAllCalls += 1;
    final response = _responses[_nextResponseIndex];
    _nextResponseIndex += 1;
    return response.future;
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

DocumentModel _document(int id, String title) {
  final now = DateTime(2026, 1, id);
  return DocumentModel(
    id: id,
    title: title,
    documentType: null,
    correspondent: null,
    created: now,
    modified: now,
    added: now,
  );
}

void main() {
  test('search restores cached results while offline', () async {
    final cache = _InMemoryCacheStore()
      ..cachedPage = PagedSearchResult<DocumentModel>(
        count: 1,
        results: [_document(1, 'invoice jan')],
      );
    final api = _FakeDocumentsApi(
      response: PagedSearchResult<DocumentModel>(
        count: 1,
        results: [_document(2, 'invoice network')],
      ),
    );
    final notifier = DocumentChangedNotifier();
    final cubit = DocumentSearchCubit(
      api,
      notifier,
      _InMemoryLocalUserAppState(userId: 'u1'),
      ConnectivityStatusServiceMock(false),
      documentListCacheStore: cache,
    );

    await cubit.search('invoice');

    expect(api.findAllCalls, 0);
    expect(cache.readCalls, 1);
    expect(cache.writeCalls, 1);
    expect(cubit.state.documents.map((d) => d.id).toList(), [1]);
    expect(cubit.state.searchHistory.first, 'invoice');

    await cubit.close();
    notifier.close();
  });

  test('search fetches online and persists first page snapshot', () async {
    final networkPage = PagedSearchResult<DocumentModel>(
      count: 1,
      results: [_document(5, 'invoice network')],
    );
    final cache = _InMemoryCacheStore();
    final api = _FakeDocumentsApi(response: networkPage);
    final notifier = DocumentChangedNotifier();
    final cubit = DocumentSearchCubit(
      api,
      notifier,
      _InMemoryLocalUserAppState(userId: 'u2'),
      ConnectivityStatusServiceMock(true),
      documentListCacheStore: cache,
    );

    await cubit.search('invoice');

    expect(api.findAllCalls, 1);
    expect(cache.readCalls, 1);
    expect(cache.writeCalls, 1);
    expect(cache.cachedPage?.results.map((d) => d.id).toList(), [5]);

    await cubit.close();
    notifier.close();
  });

  test('suggest uses in-memory cache to avoid duplicate API calls', () async {
    final cache = _InMemoryCacheStore();
    final api = _FakeDocumentsApi(
      response: const PagedSearchResult<DocumentModel>(count: 0, results: []),
    );
    final notifier = DocumentChangedNotifier();
    final cubit = DocumentSearchCubit(
      api,
      notifier,
      _InMemoryLocalUserAppState(userId: 'u3'),
      ConnectivityStatusServiceMock(true),
      documentListCacheStore: cache,
    );

    await cubit.suggest('invoice');
    await cubit.suggest('invoice');

    expect(api.autocompleteCalls, 1);
    expect(cubit.state.suggestions, ['invoice-1', 'invoice-2']);

    await cubit.close();
    notifier.close();
  });

  test(
    'suggest evicts oldest cache entries once capacity is exceeded',
    () async {
      final cache = _InMemoryCacheStore();
      final api = _FakeDocumentsApi(
        response: const PagedSearchResult<DocumentModel>(count: 0, results: []),
      );
      final notifier = DocumentChangedNotifier();
      final cubit = DocumentSearchCubit(
        api,
        notifier,
        _InMemoryLocalUserAppState(userId: 'u4'),
        ConnectivityStatusServiceMock(true),
        documentListCacheStore: cache,
      );

      for (var i = 0; i < 101; i++) {
        final query = 'q${i.toString().padLeft(2, '0')}';
        await cubit.suggest(query);
      }
      expect(api.autocompleteCalls, 101);

      await cubit.suggest('q00');

      expect(api.autocompleteCalls, 102);
      expect(cubit.state.suggestions, ['q00-1', 'q00-2']);

      await cubit.close();
      notifier.close();
    },
  );

  test('suggest uses LRU behavior when cache entry is re-accessed', () async {
    final cache = _InMemoryCacheStore();
    final api = _FakeDocumentsApi(
      response: const PagedSearchResult<DocumentModel>(count: 0, results: []),
    );
    final notifier = DocumentChangedNotifier();
    final cubit = DocumentSearchCubit(
      api,
      notifier,
      _InMemoryLocalUserAppState(userId: 'u5'),
      ConnectivityStatusServiceMock(true),
      documentListCacheStore: cache,
    );

    for (var i = 0; i < 100; i++) {
      final query = 'l${i.toString().padLeft(2, '0')}';
      await cubit.suggest(query);
    }
    expect(api.autocompleteCalls, 100);

    await cubit.suggest('l00');
    expect(api.autocompleteCalls, 100);

    await cubit.suggest('l100');
    expect(api.autocompleteCalls, 101);

    await cubit.suggest('l00');
    expect(api.autocompleteCalls, 101);

    await cubit.suggest('l01');
    expect(api.autocompleteCalls, 102);

    await cubit.close();
    notifier.close();
  });

  test(
    'search keeps only latest request result when queries overlap',
    () async {
      final firstPage = Completer<PagedSearchResult<DocumentModel>>();
      final secondPage = Completer<PagedSearchResult<DocumentModel>>();
      final api = _SequencedDocumentsApi(responses: [firstPage, secondPage]);
      final notifier = DocumentChangedNotifier();
      final cache = _InMemoryCacheStore();
      final cubit = DocumentSearchCubit(
        api,
        notifier,
        _InMemoryLocalUserAppState(userId: 'u6'),
        ConnectivityStatusServiceMock(true),
        documentListCacheStore: cache,
      );

      final firstSearch = cubit.search('invoice');
      final secondSearch = cubit.search('invoice 2026');

      secondPage.complete(
        PagedSearchResult(count: 1, results: [_document(2, 'invoice 2026')]),
      );
      firstPage.complete(
        PagedSearchResult(count: 1, results: [_document(1, 'invoice old')]),
      );

      await Future.wait([firstSearch, secondSearch]);

      expect(api.findAllCalls, 2);
      expect(cache.writeCalls, 1);
      expect(cubit.state.documents.map((document) => document.id).toList(), [
        2,
      ]);
      expect(cubit.state.searchHistory, ['invoice 2026']);

      await cubit.close();
      notifier.close();
    },
  );
}
