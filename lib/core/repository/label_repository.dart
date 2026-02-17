import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/repository/label_cache_store.dart';
import 'package:paperless_mobile/features/logging/data/logger.dart';

class LabelRepository extends ChangeNotifier {
  final PaperlessLabelsApi _api;
  final String? _userId;
  final LabelCacheStore _cacheStore;

  Map<int, Correspondent> correspondents = {};
  Map<int, DocumentType> documentTypes = {};
  Map<int, StoragePath> storagePaths = {};
  Map<int, Tag> tags = {};
  bool _batchRefreshActive = false;
  bool _batchRefreshHasChanges = false;

  LabelRepository(this._api, {String? userId, LabelCacheStore? cacheStore})
    : _userId = userId,
      _cacheStore = cacheStore ?? HiveLabelCacheStore();

  // Resets the repository to its initial state and loads all data from the API.
  Future<void> initialize({
    required bool loadCorrespondents,
    required bool loadDocumentTypes,
    required bool loadStoragePaths,
    required bool loadTags,
  }) async {
    correspondents = {};
    documentTypes = {};
    storagePaths = {};
    tags = {};
    await _restoreCache(
      loadCorrespondents: loadCorrespondents,
      loadDocumentTypes: loadDocumentTypes,
      loadStoragePaths: loadStoragePaths,
      loadTags: loadTags,
    );
    _batchRefreshActive = true;
    _batchRefreshHasChanges = false;
    try {
      await Future.wait([
        if (loadCorrespondents)
          _refreshSafely('findAllCorrespondents', () async {
            await findAllCorrespondents();
          }),
        if (loadDocumentTypes)
          _refreshSafely('findAllDocumentTypes', () async {
            await findAllDocumentTypes();
          }),
        if (loadStoragePaths)
          _refreshSafely('findAllStoragePaths', () async {
            await findAllStoragePaths();
          }),
        if (loadTags)
          _refreshSafely('findAllTags', () async {
            await findAllTags();
          }),
      ]);
    } finally {
      _batchRefreshActive = false;
    }
    if (_batchRefreshHasChanges) {
      _batchRefreshHasChanges = false;
      await _persistCache();
      notifyListeners();
    }
  }

  Future<Tag> createTag(Tag object) async {
    final created = await _api.saveTag(object);
    tags = {...tags, created.id!: created};
    await _persistCache();
    notifyListeners();
    return created;
  }

  Future<int> deleteTag(Tag tag) async {
    await _api.deleteTag(tag);
    tags = {...tags}..remove(tag.id!);
    await _persistCache();
    notifyListeners();
    return tag.id!;
  }

  Future<Tag?> findTag(int id) async {
    final tag = await _api.getTag(id);
    if (tag != null) {
      tags = {...tags, id: tag};
      await _persistCache();
      notifyListeners();
      return tag;
    }
    return null;
  }

  Future<Iterable<Tag>> findAllTags([Iterable<int>? ids]) async {
    logger.fd(
      "Loading ${ids?.isEmpty ?? true ? "all" : "a subset of"} tags"
      "${ids?.isEmpty ?? true ? "" : " (${ids!.join(",")})"}...",
      className: runtimeType.toString(),
      methodName: "findAllTags",
    );
    final data = await _api.getTags(ids);
    if (ids?.isNotEmpty ?? false) {
      logger.fd(
        "Successfully updated subset of tags: ${ids!.join(",")}",
        className: runtimeType.toString(),
        methodName: "findAllTags",
      );
      // Only update the tags that were requested, keep existing ones.
      tags = {...tags, for (var tag in data) tag.id!: tag};
    } else {
      logger.fd(
        "Successfully updated all tags.",
        className: runtimeType.toString(),
        methodName: "findAllTags",
      );
      tags = {for (var tag in data) tag.id!: tag};
    }
    await _persistAndNotify();
    return data;
  }

  Future<Tag> updateTag(Tag tag) async {
    final updated = await _api.updateTag(tag);
    tags = {...tags, updated.id!: updated};
    await _persistCache();
    notifyListeners();
    return updated;
  }

  Future<Correspondent> createCorrespondent(Correspondent correspondent) async {
    final created = await _api.saveCorrespondent(correspondent);
    correspondents = {...correspondents, created.id!: created};
    await _persistCache();
    notifyListeners();
    return created;
  }

  Future<int> deleteCorrespondent(Correspondent correspondent) async {
    await _api.deleteCorrespondent(correspondent);
    correspondents = {...correspondents}..remove(correspondent.id!);
    await _persistCache();
    notifyListeners();
    return correspondent.id!;
  }

  Future<Correspondent?> findCorrespondent(int id) async {
    final correspondent = await _api.getCorrespondent(id);
    if (correspondent != null) {
      correspondents = {...correspondents, id: correspondent};
      await _persistCache();
      notifyListeners();
      return correspondent;
    }
    return null;
  }

  Future<Iterable<Correspondent>> findAllCorrespondents() async {
    final data = await _api.getCorrespondents();
    correspondents = {for (var element in data) element.id!: element};
    await _persistAndNotify();
    return data;
  }

  Future<Correspondent> updateCorrespondent(Correspondent correspondent) async {
    final updated = await _api.updateCorrespondent(correspondent);
    correspondents = {...correspondents, updated.id!: updated};
    await _persistCache();
    notifyListeners();
    return updated;
  }

  Future<DocumentType> createDocumentType(DocumentType documentType) async {
    final created = await _api.saveDocumentType(documentType);
    documentTypes = {...documentTypes, created.id!: created};
    await _persistCache();
    notifyListeners();
    return created;
  }

  Future<int> deleteDocumentType(DocumentType documentType) async {
    await _api.deleteDocumentType(documentType);
    documentTypes = {...documentTypes}..remove(documentType.id!);
    await _persistCache();
    notifyListeners();
    return documentType.id!;
  }

  Future<DocumentType?> findDocumentType(int id) async {
    final documentType = await _api.getDocumentType(id);
    if (documentType != null) {
      documentTypes = {...documentTypes, id: documentType};
      await _persistCache();
      notifyListeners();
      return documentType;
    }
    return null;
  }

  Future<Iterable<DocumentType>> findAllDocumentTypes() async {
    final documentTypes = await _api.getDocumentTypes();
    this.documentTypes = {for (var dt in documentTypes) dt.id!: dt};
    await _persistAndNotify();
    return documentTypes;
  }

  Future<DocumentType> updateDocumentType(DocumentType documentType) async {
    final updated = await _api.updateDocumentType(documentType);
    documentTypes = {...documentTypes, updated.id!: updated};
    await _persistCache();
    notifyListeners();
    return updated;
  }

  Future<StoragePath> createStoragePath(StoragePath storagePath) async {
    final created = await _api.saveStoragePath(storagePath);
    storagePaths = {...storagePaths, created.id!: created};
    await _persistCache();
    notifyListeners();
    return created;
  }

  Future<int> deleteStoragePath(StoragePath storagePath) async {
    await _api.deleteStoragePath(storagePath);
    storagePaths = {...storagePaths}..remove(storagePath.id!);
    await _persistCache();
    notifyListeners();
    return storagePath.id!;
  }

  Future<StoragePath?> findStoragePath(int id) async {
    final storagePath = await _api.getStoragePath(id);
    if (storagePath != null) {
      storagePaths = {...storagePaths, id: storagePath};
      await _persistCache();
      notifyListeners();
      return storagePath;
    }
    return null;
  }

  Future<Iterable<StoragePath>> findAllStoragePaths() async {
    final storagePaths = await _api.getStoragePaths();
    this.storagePaths = {for (var sp in storagePaths) sp.id!: sp};
    await _persistAndNotify();
    return storagePaths;
  }

  Future<StoragePath> updateStoragePath(StoragePath storagePath) async {
    final updated = await _api.updateStoragePath(storagePath);
    storagePaths = {...storagePaths, updated.id!: updated};
    await _persistCache();
    notifyListeners();
    return updated;
  }

  Future<void> _restoreCache({
    required bool loadCorrespondents,
    required bool loadDocumentTypes,
    required bool loadStoragePaths,
    required bool loadTags,
  }) async {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    final snapshot = await _cacheStore.read(userId: userId);
    if (snapshot == null) {
      return;
    }

    if (loadCorrespondents) {
      correspondents = {
        for (final item in snapshot.correspondents)
          if (item.id != null) item.id!: item,
      };
    }
    if (loadDocumentTypes) {
      documentTypes = {
        for (final item in snapshot.documentTypes)
          if (item.id != null) item.id!: item,
      };
    }
    if (loadStoragePaths) {
      storagePaths = {
        for (final item in snapshot.storagePaths)
          if (item.id != null) item.id!: item,
      };
    }
    if (loadTags) {
      tags = {
        for (final item in snapshot.tags)
          if (item.id != null) item.id!: item,
      };
    }
    if (loadCorrespondents ||
        loadDocumentTypes ||
        loadStoragePaths ||
        loadTags) {
      notifyListeners();
    }
  }

  Future<void> _persistCache() async {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    await _cacheStore.write(
      userId: userId,
      snapshot: LabelCacheSnapshot(
        correspondents: correspondents.values.toList(growable: false),
        documentTypes: documentTypes.values.toList(growable: false),
        storagePaths: storagePaths.values.toList(growable: false),
        tags: tags.values.toList(growable: false),
      ),
    );
  }

  Future<void> _persistAndNotify() async {
    if (_batchRefreshActive) {
      _batchRefreshHasChanges = true;
      return;
    }
    await _persistCache();
    notifyListeners();
  }

  Future<void> _refreshSafely(
    String operation,
    Future<void> Function() refresh,
  ) async {
    try {
      await refresh();
    } catch (error, stackTrace) {
      logger.fw(
        'Failed to refresh labels via $operation, keeping cached values.',
        className: runtimeType.toString(),
        methodName: operation,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  // @override
  // LabelRepositoryState? fromJson(Map<String, dynamic> json) {
  //   return LabelRepositoryState.fromJson(json);
  // }

  // @override
  // Map<String, dynamic>? toJson(LabelRepositoryState state) {
  //   return state.toJson();
  // }
}
