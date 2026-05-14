import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:paperless_api/src/extensions/dio_exception_extension.dart';
import 'package:paperless_api/src/models/models.dart';
import 'package:paperless_api/src/modules/labels_api/paperless_labels_api.dart';
import 'package:paperless_api/src/request_utils.dart';

//Notes:
// Removed content type json header
class PaperlessLabelApiImpl implements PaperlessLabelsApi {
  final Dio _client;

  PaperlessLabelApiImpl(this._client);
  @override
  Future<Correspondent?> getCorrespondent(int id) async {
    return getSingleResult(
      "/api/correspondents/$id/",
      Correspondent.fromJson,
      ErrorCode.correspondentLoadFailed,
      client: _client,
    );
  }

  @override
  Future<Tag?> getTag(int id) async {
    return getSingleResult(
      "/api/tags/$id/",
      Tag.fromJson,
      ErrorCode.tagLoadFailed,
      client: _client,
    );
  }

  @override
  Future<List<Tag>> getTags([Iterable<int>? ids]) async {
    final results = await getCollection(
      "/api/tags/?page=1&page_size=100000",
      Tag.fromJson,
      ErrorCode.tagLoadFailed,
      client: _client,
    );
    return results
        .where((element) => ids?.contains(element.id) ?? true)
        .toList();
  }

  @override
  Future<DocumentType?> getDocumentType(int id) async {
    return getSingleResult(
      "/api/document_types/$id/",
      DocumentType.fromJson,
      ErrorCode.documentTypeLoadFailed,
      client: _client,
    );
  }

  @override
  Future<List<Correspondent>> getCorrespondents([Iterable<int>? ids]) async {
    final results = await getCollection(
      "/api/correspondents/?page=1&page_size=100000",
      Correspondent.fromJson,
      ErrorCode.correspondentLoadFailed,
      client: _client,
    );

    return results
        .where((element) => ids?.contains(element.id) ?? true)
        .toList();
  }

  @override
  Future<List<DocumentType>> getDocumentTypes([Iterable<int>? ids]) async {
    final results = await getCollection(
      "/api/document_types/?page=1&page_size=100000",
      DocumentType.fromJson,
      ErrorCode.documentTypeLoadFailed,
      client: _client,
    );

    return results
        .where((element) => ids?.contains(element.id) ?? true)
        .toList();
  }

  @override
  Future<Correspondent> saveCorrespondent(Correspondent correspondent) async {
    try {
      final response = await _client.post(
        '/api/correspondents/',
        data: correspondent.toJson(),
        options: Options(validateStatus: (status) => status == 201),
      );
      return Correspondent.fromJson(response.data);
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(
          ErrorCode.correspondentCreateFailed,
        ),
      );
    }
  }

  @override
  Future<DocumentType> saveDocumentType(DocumentType type) async {
    try {
      final response = await _client.post(
        '/api/document_types/',
        data: type.toJson(),
        options: Options(validateStatus: (status) => status == 201),
      );
      return DocumentType.fromJson(response.data);
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.documentTypeCreateFailed),
      );
    }
  }

  @override
  Future<Tag> saveTag(Tag tag) async {
    try {
      final response = await _client.post(
        '/api/tags/',
        data: tag.toJson(),
        options: Options(validateStatus: (status) => status == 201),
      );
      return Tag.fromJson(response.data);
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.tagCreateFailed),
      );
    }
  }

  @override
  Future<int> deleteCorrespondent(Correspondent correspondent) async {
    assert(correspondent.id != null);
    try {
      await _client.delete(
        '/api/correspondents/${correspondent.id}/',
        options: Options(validateStatus: (status) => status == 204),
      );
      return correspondent.id!;
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(
          ErrorCode.correspondentDeleteFailed,
        ),
      );
    }
  }

  @override
  Future<int> deleteDocumentType(DocumentType documentType) async {
    assert(documentType.id != null);
    try {
      await _client.delete(
        '/api/document_types/${documentType.id}/',
        options: Options(validateStatus: (status) => status == 204),
      );
      return documentType.id!;
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.documentTypeDeleteFailed),
      );
    }
  }

  @override
  Future<int> deleteTag(Tag tag) async {
    assert(tag.id != null);
    try {
      await _client.delete(
        '/api/tags/${tag.id}/',
        options: Options(validateStatus: (status) => status == 204),
      );
      return tag.id!;
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.tagDeleteFailed),
      );
    }
  }

  @override
  Future<Correspondent> updateCorrespondent(Correspondent correspondent) async {
    assert(correspondent.id != null);
    try {
      final response = await _client.put(
        '/api/correspondents/${correspondent.id}/',
        data: json.encode(correspondent.toJson()),
        options: Options(validateStatus: (status) => status == 200),
      );
      return Correspondent.fromJson(response.data);
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(
          ErrorCode.correspondentUpdateFailed,
        ),
      );
    }
  }

  @override
  Future<DocumentType> updateDocumentType(DocumentType documentType) async {
    assert(documentType.id != null);
    try {
      final response = await _client.put(
        '/api/document_types/${documentType.id}/',
        data: documentType.toJson(),
        options: Options(validateStatus: (status) => status == 200),
      );
      return DocumentType.fromJson(response.data);
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.documentTypeUpdateFailed),
      );
    }
  }

  @override
  Future<Tag> updateTag(Tag tag) async {
    assert(tag.id != null);
    try {
      final response = await _client.put(
        '/api/tags/${tag.id}/',
        options: Options(validateStatus: (status) => status == 200),
        data: tag.toJson(),
      );
      return Tag.fromJson(response.data);
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.tagUpdateFailed),
      );
    }
  }

  @override
  Future<int> deleteStoragePath(StoragePath path) async {
    assert(path.id != null);
    try {
      await _client.delete(
        '/api/storage_paths/${path.id}/',
        options: Options(validateStatus: (status) => status == 204),
      );
      return path.id!;
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.storagePathDeleteFailed),
      );
    }
  }

  @override
  Future<StoragePath?> getStoragePath(int id) {
    return getSingleResult(
      "/api/storage_paths/$id/",
      StoragePath.fromJson,
      ErrorCode.storagePathLoadFailed,
      client: _client,
    );
  }

  @override
  Future<List<StoragePath>> getStoragePaths([Iterable<int>? ids]) async {
    final results = await getCollection(
      "/api/storage_paths/?page=1&page_size=100000",
      StoragePath.fromJson,
      ErrorCode.storagePathLoadFailed,
      client: _client,
    );

    return results
        .where((element) => ids?.contains(element.id) ?? true)
        .toList();
  }

  @override
  Future<StoragePath> saveStoragePath(StoragePath path) async {
    try {
      final response = await _client.post(
        '/api/storage_paths/',
        data: path.toJson(),
        options: Options(validateStatus: (status) => status == 201),
      );
      return StoragePath.fromJson(response.data);
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.storagePathCreateFailed),
      );
    }
  }

  @override
  Future<StoragePath> updateStoragePath(StoragePath path) async {
    assert(path.id != null);
    try {
      final response = await _client.put(
        '/api/storage_paths/${path.id}/',
        data: path.toJson(),
        options: Options(validateStatus: (status) => status == 200),
      );
      return StoragePath.fromJson(response.data);
    } on DioException catch (exception) {
      throw exception.unravel(
        orElse: const PaperlessApiException(ErrorCode.storagePathUpdateFailed),
      );
    }
  }
}
