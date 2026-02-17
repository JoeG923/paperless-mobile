import 'dart:async';

import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_app_state.dart';
import 'package:paperless_mobile/core/extensions/document_extensions.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/core/repository/document_list_cache_coordinator.dart';
import 'package:paperless_mobile/core/repository/document_list_cache_store.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/paged_document_view/cubit/document_paging_bloc_mixin.dart';
import 'package:paperless_mobile/features/paged_document_view/cubit/paged_documents_state.dart';
import 'package:paperless_mobile/features/settings/model/view_type.dart';

part 'documents_state.dart';

class DocumentsCubit extends Cubit<DocumentsState>
    with DocumentPagingBlocMixin {
  @override
  final PaperlessDocumentsApi api;

  @override
  final ConnectivityStatusService connectivityStatusService;

  @override
  final DocumentChangedNotifier notifier;

  final LocalUserAppState _userState;
  final DocumentListCacheCoordinator _documentListCache;

  DocumentsCubit(
    this.api,
    this.notifier,
    this._userState,
    this.connectivityStatusService, {
    DocumentListCacheStore? documentListCacheStore,
  }) : _documentListCache = DocumentListCacheCoordinator(
         documentListCacheStore ?? HiveDocumentListCacheStore(),
       ),
       super(
         DocumentsState(
           filter: _userState.currentDocumentFilter,
           viewType: _userState.documentsPageViewType,
         ),
       ) {
    notifier.addListener(
      this,
      onUpdated: (document) {
        replace(document);
        emit(
          state.copyWith(
            selection: state.selection.withDocumentreplaced(document).toList(),
          ),
        );
      },
      onDeleted: (document) {
        remove(document);
        emit(
          state.copyWith(
            selection: state.selection.withDocumentRemoved(document).toList(),
          ),
        );
      },
    );
  }

  @override
  Future<void> initialize() async {
    await _restoreCachedPage();
    await updateFilter(filter: state.filter, emitLoading: state.value.isEmpty);
  }

  Future<void> bulkDelete(List<DocumentModel> documents) async {
    await api.bulkAction(BulkDeleteAction(documents.map((doc) => doc.id)));
    for (final deletedDoc in documents) {
      notifier.notifyDeleted(deletedDoc);
    }
    await reload();
  }

  Future<void> bulkReprocess(List<DocumentModel> documents) async {
    await api.bulkAction(BulkReprocessAction(documents.map((doc) => doc.id)));
    await reload();
  }

  Future<void> bulkMerge(
    List<DocumentModel> documents, {
    bool? deleteOriginals,
    int? metadataDocumentId,
    bool? archiveFallback,
  }) async {
    await api.bulkAction(
      BulkMergeAction(
        documents.map((doc) => doc.id),
        deleteOriginals: deleteOriginals,
        metadataDocumentId: metadataDocumentId,
        archiveFallback: archiveFallback,
      ),
    );
    await reload();
  }

  Future<void> bulkRotate(
    List<DocumentModel> documents, {
    required int degrees,
  }) async {
    await api.bulkAction(
      BulkRotateAction(documents.map((doc) => doc.id), degrees: degrees),
    );
    await reload();
  }

  Future<void> bulkSplit(
    DocumentModel document, {
    required String pages,
    bool? deleteOriginals,
  }) async {
    await api.bulkAction(
      BulkSplitAction(
        [document.id],
        pages: pages,
        deleteOriginals: deleteOriginals,
      ),
    );
    await reload();
  }

  Future<void> bulkDeletePages(
    DocumentModel document, {
    required Iterable<int> pages,
  }) async {
    await api.bulkAction(BulkDeletePagesAction([document.id], pages: pages));
    await reload();
  }

  Future<void> bulkModifyCustomFields(
    List<DocumentModel> documents, {
    required BulkCustomFieldPayload addCustomFields,
    Iterable<int> removeCustomFields = const [],
  }) async {
    await api.bulkAction(
      BulkModifyCustomFieldsAction(
        documents.map((doc) => doc.id),
        addCustomFields: addCustomFields,
        removeCustomFields: removeCustomFields,
      ),
    );
    await reload();
  }

  Future<void> bulkSetPermissions(
    List<DocumentModel> documents, {
    required Map<String, dynamic> permissions,
    bool merge = false,
    int? owner,
  }) async {
    await api.bulkAction(
      BulkSetPermissionsAction(
        documents.map((doc) => doc.id),
        setPermissions: permissions,
        merge: merge,
        owner: owner,
      ),
    );
    await reload();
  }

  Future<void> bulkEditPdf(
    List<DocumentModel> documents, {
    required Iterable<Map<String, Object?>> operations,
    bool updateDocument = false,
    bool includeMetadata = true,
  }) async {
    await api.bulkAction(
      BulkEditPdfAction(
        documents.map((doc) => doc.id),
        operations: operations,
        updateDocument: updateDocument,
        includeMetadata: includeMetadata,
      ),
    );
    await reload();
  }

  Future<void> bulkRemovePassword(
    List<DocumentModel> documents, {
    required String password,
  }) async {
    await api.bulkAction(
      BulkRemovePasswordAction(
        documents.map((doc) => doc.id),
        password: password,
      ),
    );
    await reload();
  }

  void toggleDocumentSelection(DocumentModel model) {
    if (state.selectedIds.contains(model.id)) {
      emit(
        state.copyWith(
          selection: state.selection
              .where((element) => element.id != model.id)
              .toList(),
        ),
      );
    } else {
      emit(state.copyWith(selection: [...state.selection, model]));
    }
  }

  void resetSelection() {
    emit(state.copyWith(selection: []));
  }

  void reset() {
    emit(const DocumentsState());
  }

  Future<Iterable<String>> autocomplete(String query) async {
    final res = await api.autocomplete(query);
    return res;
  }

  @override
  Future<void> close() {
    notifier.removeListener(this);
    return super.close();
  }

  void setViewType(ViewType viewType) {
    emit(state.copyWith(viewType: viewType));
    _userState
      ..documentsPageViewType = viewType
      ..save();
  }

  @override
  Future<void> onFilterUpdated(DocumentFilter filter) async {
    _userState.currentDocumentFilter = filter;
    await _userState.save();
  }

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

  Future<void> _restoreCachedPage() async {
    final cachedPage = await _documentListCache.restore(
      userId: _userState.userId,
      filter: state.filter,
    );
    if (cachedPage == null || isClosed) {
      return;
    }
    emit(state.copyWith(hasLoaded: true, value: [cachedPage]));
  }

  Future<void> _persistFirstPage() async {
    await _documentListCache.persistFirstPage(
      userId: _userState.userId,
      filter: state.filter,
      pages: state.value,
    );
  }

  // @override
  // DocumentsState? fromJson(Map<String, dynamic> json) {
  //   return DocumentsState.fromJson(json);
  // }

  // @override
  // Map<String, dynamic>? toJson(DocumentsState state) {
  //   return state.toJson();
  // }
}
