import 'package:equatable/equatable.dart';
import 'package:paperless_api/src/converters/local_date_time_json_converter.dart';
import 'package:paperless_api/src/models/field_suggestions.dart';

class AiDocumentSuggestions extends FieldSuggestions with EquatableMixin {
  final String? title;
  final Iterable<String> suggestedCorrespondents;
  final Iterable<String> suggestedTags;
  final Iterable<String> suggestedDocumentTypes;
  final Iterable<String> suggestedStoragePaths;

  const AiDocumentSuggestions({
    super.documentId,
    this.title,
    super.correspondents = const [],
    this.suggestedCorrespondents = const [],
    super.tags = const [],
    this.suggestedTags = const [],
    super.documentTypes = const [],
    this.suggestedDocumentTypes = const [],
    super.storagePaths = const [],
    this.suggestedStoragePaths = const [],
    super.dates = const [],
  });

  factory AiDocumentSuggestions.fromJson(Map<String, dynamic> json) {
    return AiDocumentSuggestions(
      title: json['title'] as String?,
      correspondents: _intList(json['correspondents']),
      suggestedCorrespondents: _stringList(json['suggested_correspondents']),
      tags: _intList(json['tags']),
      suggestedTags: _stringList(json['suggested_tags']),
      documentTypes: _intList(json['document_types']),
      suggestedDocumentTypes: _stringList(json['suggested_document_types']),
      storagePaths: _intList(json['storage_paths']),
      suggestedStoragePaths: _stringList(json['suggested_storage_paths']),
      dates: _dateList(json['dates']),
    );
  }

  @override
  AiDocumentSuggestions forDocumentId(int id) => AiDocumentSuggestions(
    documentId: id,
    title: title,
    correspondents: correspondents,
    suggestedCorrespondents: suggestedCorrespondents,
    tags: tags,
    suggestedTags: suggestedTags,
    documentTypes: documentTypes,
    suggestedDocumentTypes: suggestedDocumentTypes,
    storagePaths: storagePaths,
    suggestedStoragePaths: suggestedStoragePaths,
    dates: dates,
  );

  bool get hasSuggestedNewLabels =>
      suggestedCorrespondents.isNotEmpty ||
      suggestedTags.isNotEmpty ||
      suggestedDocumentTypes.isNotEmpty ||
      suggestedStoragePaths.isNotEmpty;

  @override
  bool get hasSuggestions =>
      super.hasSuggestions || title != null || hasSuggestedNewLabels;

  @override
  List<Object?> get props => [
    ...super.props,
    title,
    suggestedCorrespondents,
    suggestedTags,
    suggestedDocumentTypes,
    suggestedStoragePaths,
  ];
}

List<int> _intList(Object? value) {
  if (value is! Iterable) return const [];
  return value.whereType<num>().map((value) => value.toInt()).toList();
}

List<String> _stringList(Object? value) {
  if (value is! Iterable) return const [];
  return value.whereType<String>().toList();
}

List<DateTime> _dateList(Object? value) {
  if (value is! Iterable) return const [];
  const converter = LocalDateTimeJsonConverter();
  return value
      .whereType<String>()
      .map(converter.fromJson)
      .whereType<DateTime>()
      .toList();
}
