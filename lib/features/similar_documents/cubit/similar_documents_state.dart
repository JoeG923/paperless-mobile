part of 'similar_documents_cubit.dart';

class SimilarDocumentsState extends DocumentPagingState {
  final ErrorCode? error;
  const SimilarDocumentsState({
    required super.filter,
    super.hasLoaded,
    super.isLoading,
    super.value,
    this.error,
  });

  @override
  List<Object?> get props => [filter, hasLoaded, isLoading, value, error];

  @override
  SimilarDocumentsState copyWithPaged({
    bool? hasLoaded,
    bool? isLoading,
    List<PagedSearchResult<DocumentModel>>? value,
    DocumentFilter? filter,
  }) {
    return copyWith(
      hasLoaded: hasLoaded,
      isLoading: isLoading,
      value: value,
      filter: filter,
    );
  }

  SimilarDocumentsState copyWith({
    bool? hasLoaded,
    bool? isLoading,
    List<PagedSearchResult<DocumentModel>>? value,
    DocumentFilter? filter,
    ErrorCode? error,
  }) {
    return SimilarDocumentsState(
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isLoading: isLoading ?? this.isLoading,
      value: value ?? this.value,
      filter: filter ?? this.filter,
      error: error,
    );
  }
}
