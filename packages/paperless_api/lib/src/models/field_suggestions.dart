import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:paperless_api/src/converters/local_date_time_json_converter.dart';
import 'package:paperless_api/src/models/document_model.dart';

part 'field_suggestions.g.dart';

@LocalDateTimeJsonConverter()
@JsonSerializable(fieldRename: FieldRename.snake)
class FieldSuggestions with EquatableMixin {
  final int? documentId;
  final Iterable<int> correspondents;
  final Iterable<int> tags;
  final Iterable<int> documentTypes;
  final Iterable<DateTime> dates;

  const FieldSuggestions({
    this.documentId,
    this.correspondents = const [],
    this.tags = const [],
    this.documentTypes = const [],
    this.dates = const [],
  });

  bool get hasSuggestedCorrespondents => correspondents.isNotEmpty;
  bool get hasSuggestedTags => tags.isNotEmpty;
  bool get hasSuggestedDocumentTypes => documentTypes.isNotEmpty;
  bool get hasSuggestedDates => dates.isNotEmpty;

  bool get hasSuggestions =>
      hasSuggestedCorrespondents ||
      hasSuggestedDates ||
      hasSuggestedTags ||
      hasSuggestedDocumentTypes;

  int get suggestionsCount =>
      (correspondents.isNotEmpty ? 1 : 0) +
      (tags.isNotEmpty ? 1 : 0) +
      (documentTypes.isNotEmpty ? 1 : 0) +
      (dates.isNotEmpty ? 1 : 0);

  FieldSuggestions forDocumentId(int id) => FieldSuggestions(
    documentId: id,
    correspondents: correspondents,
    dates: dates,
    documentTypes: documentTypes,
    tags: tags,
  );

  ///
  /// Removes the suggestions given in the parameters.
  ///
  FieldSuggestions difference({
    Iterable<int> tags = const {},
    Iterable<int> correspondents = const {},
    Iterable<int> documentTypes = const {},
    Iterable<DateTime> dates = const {},
  }) {
    return copyWith(
      tags: this.tags.toSet().difference(tags.toSet()),
      correspondents: this.correspondents.toSet().difference(
        correspondents.toSet(),
      ),
      documentTypes: this.documentTypes.toSet().difference(
        documentTypes.toSet(),
      ),
      dates: this.dates.toSet().difference(dates.toSet()),
    );
  }

  FieldSuggestions documentDifference(DocumentModel document) {
    return difference(
      tags: document.tags,
      correspondents: [
        document.correspondent,
      ].where((e) => e != null).map((e) => e!),
      documentTypes: [
        document.documentType,
      ].where((e) => e != null).map((e) => e!),
      dates: [document.created],
    );
  }

  FieldSuggestions copyWith({
    Iterable<int>? tags,
    Iterable<int>? correspondents,
    Iterable<int>? documentTypes,
    Iterable<DateTime>? dates,
    int? documentId,
  }) {
    return FieldSuggestions(
      tags: tags ?? this.tags,
      correspondents: correspondents ?? this.correspondents,
      dates: dates ?? this.dates,
      documentId: documentId ?? this.documentId,
    );
  }

  factory FieldSuggestions.fromJson(Map<String, dynamic> json) =>
      _$FieldSuggestionsFromJson(json);

  Map<String, dynamic> toJson() => _$FieldSuggestionsToJson(this);

  @override
  List<Object?> get props => [
    documentId,
    correspondents,
    tags,
    documentTypes,
    dates,
  ];
}
