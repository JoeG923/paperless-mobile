part of 'linked_documents_cubit.dart';

@JsonSerializable(ignoreUnannotated: true)
class LinkedDocumentsState extends DocumentPagingState {
  @JsonKey()
  final ViewType viewType;

  const LinkedDocumentsState({
    this.viewType = ViewType.list,
    super.filter = const DocumentFilter(),
    super.isLoading,
    super.hasLoaded,
    super.value,
  });

  LinkedDocumentsState copyWith({
    DocumentFilter? filter,
    bool? isLoading,
    bool? hasLoaded,
    List<PagedSearchResult<DocumentModel>>? value,
    ViewType? viewType,
    Map<int, Correspondent>? correspondents,
    Map<int, DocumentType>? documentTypes,
    Map<int, StoragePath>? storagePaths,
    Map<int, Tag>? tags,
  }) {
    return LinkedDocumentsState(
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      value: value ?? this.value,
      viewType: viewType ?? this.viewType,
    );
  }

  @override
  LinkedDocumentsState copyWithPaged({
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

  @override
  List<Object?> get props => [viewType, ...super.props];

  factory LinkedDocumentsState.fromJson(Map<String, dynamic> json) =>
      _$LinkedDocumentsStateFromJson(json);

  Map<String, dynamic> toJson() => _$LinkedDocumentsStateToJson(this);
}
