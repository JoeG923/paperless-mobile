import 'package:bloc/bloc.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/core/repository/document_list_cache_store.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/logging/data/logger.dart';
import 'package:paperless_mobile/features/paged_document_view/cubit/document_paging_bloc_mixin.dart';
import 'package:paperless_mobile/features/paged_document_view/cubit/paged_documents_state.dart';

part 'similar_documents_state.dart';

class SimilarDocumentsCubit extends Cubit<SimilarDocumentsState>
    with DocumentPagingBlocMixin {
  final int documentId;
  @override
  final ConnectivityStatusService connectivityStatusService;

  @override
  final PaperlessDocumentsApi api;

  @override
  final DocumentChangedNotifier notifier;
  final String _userId;
  final DocumentListCacheStore _documentListCacheStore;

  SimilarDocumentsCubit(
    this.api,
    this.notifier,
    this.connectivityStatusService, {
    required this.documentId,
    required String userId,
    DocumentListCacheStore? documentListCacheStore,
  }) : _userId = userId,
       _documentListCacheStore =
           documentListCacheStore ?? HiveDocumentListCacheStore(),
       super(const SimilarDocumentsState(filter: DocumentFilter())) {
    notifier.addListener(this, onDeleted: remove, onUpdated: replace);
  }

  @override
  Future<void> initialize() async {
    if (!state.hasLoaded) {
      final filter = state.filter.copyWith(
        moreLike: () => documentId,
        sortField: SortField.score,
      );
      try {
        await _restoreCachedPage(filter);
        await updateFilter(filter: filter, emitLoading: state.value.isEmpty);
        emit(state.copyWith(error: null));
      } on PaperlessApiException catch (e, stackTrace) {
        logger.fe(
          "An error occurred while loading similar documents for document $documentId",
          className: "SimilarDocumentsCubit",
          methodName: "initialize",
          error: e.details,
          stackTrace: stackTrace,
        );
        emit(state.copyWith(error: e.code));
      }
    }
  }

  @override
  Future<void> close() {
    notifier.removeListener(this);
    return super.close();
  }

  @override
  Future<void> onFilterUpdated(DocumentFilter filter) async {}

  @override
  Future<void> updateFilter({
    DocumentFilter filter = const DocumentFilter(),
    bool emitLoading = true,
  }) async {
    await super.updateFilter(filter: filter, emitLoading: emitLoading);
    await _persistFirstPage();
  }

  @override
  Future<void> reload() async {
    await super.reload();
    await _persistFirstPage();
  }

  Future<void> _restoreCachedPage(DocumentFilter filter) async {
    final cachedPage = await _documentListCacheStore.read(
      userId: _userId,
      filter: filter,
    );
    if (cachedPage == null || isClosed) {
      return;
    }
    emit(state.copyWith(filter: filter, hasLoaded: true, value: [cachedPage]));
  }

  Future<void> _persistFirstPage() async {
    if (state.value.isEmpty) {
      return;
    }
    await _documentListCacheStore.write(
      userId: _userId,
      filter: state.filter,
      page: state.value.first,
    );
  }
}
