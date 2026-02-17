import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/repository/document_list_cache_store.dart';

class DocumentListCacheCoordinator {
  final DocumentListCacheStore _store;

  DocumentListCacheCoordinator(this._store);

  Future<PagedSearchResult<DocumentModel>?> restore({
    required String userId,
    required DocumentFilter filter,
  }) {
    return _store.read(userId: userId, filter: filter);
  }

  Future<void> persistFirstPage({
    required String userId,
    required DocumentFilter filter,
    required List<PagedSearchResult<DocumentModel>> pages,
  }) async {
    if (pages.isEmpty) {
      return;
    }
    await _store.write(userId: userId, filter: filter, page: pages.first);
  }
}
