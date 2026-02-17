abstract class BulkAction {
  final Iterable<int> documentIds;

  BulkAction(this.documentIds);

  Map<String, dynamic> toJson();
}

sealed class BulkCustomFieldPayload {
  const BulkCustomFieldPayload();

  Object toJson();

  factory BulkCustomFieldPayload.ids(Iterable<int> ids) =
      BulkCustomFieldIdPayload;
  factory BulkCustomFieldPayload.values(Map<int, Object?> values) =
      BulkCustomFieldValuePayload;
}

class BulkCustomFieldIdPayload extends BulkCustomFieldPayload {
  final List<int> ids;

  BulkCustomFieldIdPayload(Iterable<int> ids) : ids = List.unmodifiable(ids);

  @override
  Object toJson() => ids;
}

class BulkCustomFieldValuePayload extends BulkCustomFieldPayload {
  final Map<int, Object?> values;

  BulkCustomFieldValuePayload(Map<int, Object?> values)
    : values = Map.unmodifiable(values);

  @override
  Object toJson() => {
    for (final entry in values.entries) '${entry.key}': entry.value,
  };
}

class BulkDeleteAction extends BulkAction {
  BulkDeleteAction(super.documents);

  @override
  Map<String, dynamic> toJson() {
    return {
      'documents': documentIds.toList(),
      'method': 'delete',
      'parameters': {},
    };
  }
}

class BulkModifyTagsAction extends BulkAction {
  final Iterable<int> removeTags;
  final Iterable<int> addTags;

  BulkModifyTagsAction(
    super.documents, {
    this.removeTags = const [],
    this.addTags = const [],
  });

  BulkModifyTagsAction.addTags(super.documents, this.addTags)
    : removeTags = const [];

  BulkModifyTagsAction.removeTags(super.documents, Iterable<int> tags)
    : addTags = const [],
      removeTags = tags;

  @override
  Map<String, dynamic> toJson() {
    return {
      'documents': documentIds.toList(),
      'method': 'modify_tags',
      'parameters': {
        'add_tags': addTags.toList(),
        'remove_tags': removeTags.toList(),
      },
    };
  }
}

class BulkModifyLabelAction extends BulkAction {
  final String _labelName;
  final int? labelId;

  BulkModifyLabelAction.correspondent(super.documents, {required this.labelId})
    : _labelName = 'correspondent';

  BulkModifyLabelAction.documentType(super.documents, {required this.labelId})
    : _labelName = 'document_type';

  BulkModifyLabelAction.storagePath(super.documents, {required this.labelId})
    : _labelName = 'storage_path';

  @override
  Map<String, dynamic> toJson() {
    return {
      'documents': documentIds.toList(),
      'method': 'set_$_labelName',
      'parameters': {_labelName: labelId},
    };
  }
}

class BulkReprocessAction extends BulkAction {
  BulkReprocessAction(super.documents);

  @override
  Map<String, dynamic> toJson() {
    return {
      'documents': documentIds.toList(),
      'method': 'reprocess',
      'parameters': const {},
    };
  }
}

class BulkRotateAction extends BulkAction {
  final int degrees;

  BulkRotateAction(super.documents, {required this.degrees});

  @override
  Map<String, dynamic> toJson() {
    return {
      'documents': documentIds.toList(),
      'method': 'rotate',
      'parameters': {'degrees': degrees},
    };
  }
}

class BulkSplitAction extends BulkAction {
  final String pages;
  final bool? deleteOriginals;

  BulkSplitAction(super.documents, {required this.pages, this.deleteOriginals});

  @override
  Map<String, dynamic> toJson() {
    final parameters = <String, dynamic>{'pages': pages};
    if (deleteOriginals != null) {
      parameters['delete_originals'] = deleteOriginals;
    }
    return {
      'documents': documentIds.toList(),
      'method': 'split',
      'parameters': parameters,
    };
  }
}

class BulkDeletePagesAction extends BulkAction {
  final Iterable<int> pages;

  BulkDeletePagesAction(super.documents, {required this.pages});

  @override
  Map<String, dynamic> toJson() {
    return {
      'documents': documentIds.toList(),
      'method': 'delete_pages',
      'parameters': {'pages': pages.toList()},
    };
  }
}

class BulkMergeAction extends BulkAction {
  final bool? deleteOriginals;
  final int? metadataDocumentId;
  final bool? archiveFallback;

  BulkMergeAction(
    super.documents, {
    this.deleteOriginals,
    this.metadataDocumentId,
    this.archiveFallback,
  });

  @override
  Map<String, dynamic> toJson() {
    final parameters = <String, dynamic>{};
    if (deleteOriginals != null) {
      parameters['delete_originals'] = deleteOriginals;
    }
    if (metadataDocumentId != null) {
      parameters['metadata_document_id'] = metadataDocumentId;
    }
    if (archiveFallback != null) {
      parameters['archive_fallback'] = archiveFallback;
    }
    return {
      'documents': documentIds.toList(),
      'method': 'merge',
      'parameters': parameters,
    };
  }
}

class BulkModifyCustomFieldsAction extends BulkAction {
  final BulkCustomFieldPayload addCustomFields;
  final Iterable<int> removeCustomFields;

  BulkModifyCustomFieldsAction(
    super.documents, {
    required this.addCustomFields,
    this.removeCustomFields = const [],
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'documents': documentIds.toList(),
      'method': 'modify_custom_fields',
      'parameters': {
        'add_custom_fields': addCustomFields.toJson(),
        'remove_custom_fields': removeCustomFields.toList(),
      },
    };
  }
}

class BulkSetPermissionsAction extends BulkAction {
  final Map<String, dynamic> setPermissions;
  final bool merge;
  final int? owner;

  BulkSetPermissionsAction(
    super.documents, {
    required this.setPermissions,
    this.merge = false,
    this.owner,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'documents': documentIds.toList(),
      'method': 'set_permissions',
      'parameters': {
        'set_permissions': setPermissions,
        'merge': merge,
        if (owner != null) 'owner': owner,
      },
    };
  }
}

class BulkEditPdfAction extends BulkAction {
  final List<Map<String, Object?>> operations;
  final bool updateDocument;
  final bool includeMetadata;

  BulkEditPdfAction(
    super.documents, {
    required Iterable<Map<String, Object?>> operations,
    this.updateDocument = false,
    this.includeMetadata = true,
  }) : operations = List.unmodifiable(
         operations.map(
           (operation) => Map<String, Object?>.unmodifiable(operation),
         ),
       );

  @override
  Map<String, dynamic> toJson() {
    return {
      'documents': documentIds.toList(),
      'method': 'edit_pdf',
      'parameters': {
        'operations': operations,
        'update_document': updateDocument,
        'include_metadata': includeMetadata,
      },
    };
  }
}

class BulkRemovePasswordAction extends BulkAction {
  final String password;

  BulkRemovePasswordAction(super.documents, {required this.password});

  @override
  Map<String, dynamic> toJson() {
    return {
      'documents': documentIds.toList(),
      'method': 'remove_password',
      'parameters': {'password': password},
    };
  }
}
