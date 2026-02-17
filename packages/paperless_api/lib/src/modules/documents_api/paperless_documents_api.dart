import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:paperless_api/src/models/models.dart';

sealed class UploadCustomFields {
  const UploadCustomFields();

  Object toJson();

  factory UploadCustomFields.ids(Iterable<int> ids) = UploadCustomFieldIds;
  factory UploadCustomFields.values(Map<int, Object?> values) =
      UploadCustomFieldValues;
}

class UploadCustomFieldIds extends UploadCustomFields {
  final List<int> ids;

  UploadCustomFieldIds(Iterable<int> values) : ids = List.unmodifiable(values);

  @override
  Object toJson() => List<int>.from(ids);
}

class UploadCustomFieldValues extends UploadCustomFields {
  final Map<int, Object?> values;

  UploadCustomFieldValues(Map<int, Object?> values)
    : values = Map.unmodifiable(values);

  @override
  Object toJson() =>
      values.map((fieldId, value) => MapEntry(fieldId.toString(), value));
}

abstract class PaperlessDocumentsApi {
  /// Uploads a document using a form data request and from server version 1.11.3
  /// returns the celery task id which can be used to track the status of the document.
  Future<String?> create(
    Uint8List documentBytes, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  });

  /// Uploads a document from the filesystem without preloading file bytes into
  /// memory and returns the server task id when available.
  Future<String?> createFromFile(
    String filePath, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  });
  Future<DocumentModel> update(DocumentModel doc);
  Future<int> findNextAsn();
  Future<PagedSearchResult<DocumentModel>> findAll(DocumentFilter filter);
  Future<DocumentModel> find(int id, {bool fullPermissions = false});
  Future<int> delete(DocumentModel doc);
  Future<DocumentMetaData> getMetaData(int id);
  Future<DocumentModel> deleteNote(DocumentModel document, int noteId);
  Future<Iterable<int>> bulkAction(BulkAction action);
  Future<Uint8List> getPreview(int docId);
  String getThumbnailUrl(int docId);
  Future<Uint8List> downloadDocument(int id, {bool original});
  Future<void> downloadToFile(
    int id,
    String localFilePath, {
    bool original = false,
    void Function(double progress)? onProgressChanged,
  });
  Future<FieldSuggestions> findSuggestions(DocumentModel document);

  Future<List<String>> autocomplete(String query, [int limit = 10]);

  Future<DocumentModel> addNote({
    required DocumentModel document,
    required String text,
  });
}
