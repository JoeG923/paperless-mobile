import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/repository/document_list_cache_coordinator.dart';
import 'package:paperless_mobile/core/repository/document_list_cache_store.dart';

class _InMemoryDocumentListCacheStore implements DocumentListCacheStore {
  PagedSearchResult<DocumentModel>? cachedPage;
  int readCalls = 0;
  int writeCalls = 0;
  String? lastReadUserId;
  DocumentFilter? lastReadFilter;
  String? lastWriteUserId;
  DocumentFilter? lastWriteFilter;
  PagedSearchResult<DocumentModel>? lastWrittenPage;

  @override
  Future<PagedSearchResult<DocumentModel>?> read({
    required String userId,
    required DocumentFilter filter,
  }) async {
    readCalls += 1;
    lastReadUserId = userId;
    lastReadFilter = filter;
    return cachedPage;
  }

  @override
  Future<void> write({
    required String userId,
    required DocumentFilter filter,
    required PagedSearchResult<DocumentModel> page,
  }) async {
    writeCalls += 1;
    lastWriteUserId = userId;
    lastWriteFilter = filter;
    lastWrittenPage = page;
    cachedPage = page;
  }
}

DocumentModel _document(int id, String title) {
  final now = DateTime(2026, 2, id);
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
  test('restore delegates to cache store with user and filter', () async {
    final store = _InMemoryDocumentListCacheStore()
      ..cachedPage = PagedSearchResult(
        count: 1,
        results: [_document(1, 'invoice')],
      );
    final coordinator = DocumentListCacheCoordinator(store);
    final filter = DocumentFilter(query: TextQuery.extended('invoice'));

    final restored = await coordinator.restore(userId: 'u1', filter: filter);

    expect(store.readCalls, 1);
    expect(store.lastReadUserId, 'u1');
    expect(store.lastReadFilter, filter);
    expect(restored?.results.map((d) => d.id).toList(), [1]);
  });

  test('persistFirstPage is a no-op for empty pages', () async {
    final store = _InMemoryDocumentListCacheStore();
    final coordinator = DocumentListCacheCoordinator(store);

    await coordinator.persistFirstPage(
      userId: 'u1',
      filter: const DocumentFilter(),
      pages: const [],
    );

    expect(store.writeCalls, 0);
  });

  test('persistFirstPage writes the first page snapshot', () async {
    final store = _InMemoryDocumentListCacheStore();
    final coordinator = DocumentListCacheCoordinator(store);
    final first = PagedSearchResult<DocumentModel>(
      count: 2,
      results: [_document(1, 'invoice-1')],
    );
    final second = PagedSearchResult<DocumentModel>(
      count: 2,
      results: [_document(2, 'invoice-2')],
    );
    final filter = DocumentFilter(query: TextQuery.extended('invoice'));

    await coordinator.persistFirstPage(
      userId: 'u2',
      filter: filter,
      pages: [first, second],
    );

    expect(store.writeCalls, 1);
    expect(store.lastWriteUserId, 'u2');
    expect(store.lastWriteFilter, filter);
    expect(store.lastWrittenPage, first);
    expect(store.cachedPage?.results.map((d) => d.id).toList(), [1]);
  });
}
