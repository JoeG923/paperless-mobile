part of 'inbox_cubit.dart';

@JsonSerializable(ignoreUnannotated: true)
class InboxState extends DocumentPagingState {
  final Iterable<int> inboxTags;

  final int itemsInInboxCount;

  @JsonKey()
  final bool isHintAcknowledged;

  const InboxState({
    super.hasLoaded = false,
    super.isLoading = false,
    super.value = const [],
    super.filter = const DocumentFilter(),
    this.inboxTags = const [],
    this.isHintAcknowledged = false,
    this.itemsInInboxCount = 0,
  });

  @override
  List<Object?> get props => [
    hasLoaded,
    isLoading,
    value,
    filter,
    inboxTags,
    documents,
    isHintAcknowledged,
    itemsInInboxCount,
  ];

  InboxState copyWith({
    bool? hasLoaded,
    bool? isLoading,
    Iterable<int>? inboxTags,
    List<PagedSearchResult<DocumentModel>>? value,
    DocumentFilter? filter,
    bool? isHintAcknowledged,
    Map<int, FieldSuggestions>? suggestions,
    int? itemsInInboxCount,
  }) {
    return InboxState(
      hasLoaded: hasLoaded ?? super.hasLoaded,
      isLoading: isLoading ?? super.isLoading,
      value: value ?? super.value,
      inboxTags: inboxTags ?? this.inboxTags,
      isHintAcknowledged: isHintAcknowledged ?? this.isHintAcknowledged,
      filter: filter ?? super.filter,
      itemsInInboxCount: itemsInInboxCount ?? this.itemsInInboxCount,
    );
  }

  factory InboxState.fromJson(Map<String, dynamic> json) =>
      _$InboxStateFromJson(json);

  Map<String, dynamic> toJson() => _$InboxStateToJson(this);

  @override
  InboxState copyWithPaged({
    bool? hasLoaded,
    bool? isLoading,
    List<PagedSearchResult<DocumentModel>>? value,
    DocumentFilter?
    filter, // Ignored as filter does not change while inbox is open
  }) {
    return copyWith(
      hasLoaded: hasLoaded,
      isLoading: isLoading,
      value: value,
      filter: filter,
    );
  }
}
