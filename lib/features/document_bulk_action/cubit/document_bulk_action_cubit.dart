import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/bloc/transient_error.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';

part 'document_bulk_action_state.dart';

class DocumentBulkActionCubit extends Cubit<DocumentBulkActionState> {
  final PaperlessDocumentsApi _documentsApi;
  final DocumentChangedNotifier _notifier;

  DocumentBulkActionCubit(
    this._documentsApi,
    this._notifier, {
    required List<DocumentModel> selection,
  }) : super(DocumentBulkActionState(selection: selection)) {
    _notifier.addListener(
      this,
      onDeleted: (document) {
        // Remove items from internal selection after the document was deleted.
        emit(
          state.copyWith(
            selection: state.selection
                .whereNot((element) => element.id == document.id)
                .toList(),
          ),
        );
      },
    );
  }

  Future<void> bulkDelete() async {
    final deletedDocumentIds = await _documentsApi.bulkAction(
      BulkDeleteAction(state.selection.map((e) => e.id).toList()),
    );
    final deletedDocuments = state.selection.where(
      (element) => deletedDocumentIds.contains(element.id),
    );
    for (final doc in deletedDocuments) {
      _notifier.notifyDeleted(doc);
    }
  }

  Future<void> bulkModifyCorrespondent(int? correspondentId) async {
    try {
      final modifiedDocumentIds = await _documentsApi.bulkAction(
        BulkModifyLabelAction.correspondent(
          state.selectedIds,
          labelId: correspondentId,
        ),
      );
      final updatedDocuments = state.selection
          .where((element) => modifiedDocumentIds.contains(element.id))
          .map((doc) => doc.copyWith(correspondent: () => correspondentId));
      for (final doc in updatedDocuments) {
        _notifier.notifyUpdated(doc);
      }
    } on PaperlessApiException catch (e) {
      addError(TransientPaperlessApiError(code: e.code, details: e.details));
    }
  }

  Future<void> bulkModifyDocumentType(int? documentTypeId) async {
    try {
      final modifiedDocumentIds = await _documentsApi.bulkAction(
        BulkModifyLabelAction.documentType(
          state.selectedIds,
          labelId: documentTypeId,
        ),
      );
      final updatedDocuments = state.selection
          .where((element) => modifiedDocumentIds.contains(element.id))
          .map((doc) => doc.copyWith(documentType: () => documentTypeId));
      for (final doc in updatedDocuments) {
        _notifier.notifyUpdated(doc);
      }
    } on PaperlessApiException catch (e) {
      addError(TransientPaperlessApiError(code: e.code, details: e.details));
    }
  }

  Future<void> bulkModifyStoragePath(int? storagePathId) async {
    try {
      final modifiedDocumentIds = await _documentsApi.bulkAction(
        BulkModifyLabelAction.storagePath(
          state.selectedIds,
          labelId: storagePathId,
        ),
      );
      final updatedDocuments = state.selection
          .where((element) => modifiedDocumentIds.contains(element.id))
          .map((doc) => doc.copyWith(storagePath: () => storagePathId));
      for (final doc in updatedDocuments) {
        _notifier.notifyUpdated(doc);
      }
    } on PaperlessApiException catch (e) {
      addError(TransientPaperlessApiError(code: e.code, details: e.details));
    }
  }

  Future<void> bulkModifyTags({
    Iterable<int> addTagIds = const [],
    Iterable<int> removeTagIds = const [],
  }) async {
    try {
      final modifiedDocumentIds = await _documentsApi.bulkAction(
        BulkModifyTagsAction(
          state.selectedIds,
          addTags: addTagIds,
          removeTags: removeTagIds,
        ),
      );
      final updatedDocuments = state.selection
          .where((element) => modifiedDocumentIds.contains(element.id))
          .map(
            (doc) => doc.copyWith(
              tags: [
                ...doc.tags.toSet().difference(removeTagIds.toSet()),
                ...addTagIds,
              ],
            ),
          );
      for (final doc in updatedDocuments) {
        _notifier.notifyUpdated(doc);
      }
    } on PaperlessApiException catch (e) {
      addError(TransientPaperlessApiError(code: e.code, details: e.details));
    }
  }

  @override
  Future<void> close() {
    _notifier.removeListener(this);
    return super.close();
  }
}
