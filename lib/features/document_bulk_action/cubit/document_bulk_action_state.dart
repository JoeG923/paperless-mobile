part of 'document_bulk_action_cubit.dart';

class DocumentBulkActionState {
  final List<DocumentModel> selection;

  DocumentBulkActionState({required this.selection});

  Iterable<int> get selectedIds => selection.map((d) => d.id);
  DocumentBulkActionState copyWith({List<DocumentModel>? selection}) {
    return DocumentBulkActionState(selection: selection ?? this.selection);
  }
}
