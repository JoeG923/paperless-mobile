abstract class BulkAction {
  final Iterable<int> documentIds;

  BulkAction(this.documentIds);

  Map<String, dynamic> toJson();
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
      }
    };
  }
}

class BulkModifyLabelAction extends BulkAction {
  final String _labelName;
  final int? labelId;

  BulkModifyLabelAction.correspondent(
    super.documents, {
    required this.labelId,
  }) : _labelName = 'correspondent';

  BulkModifyLabelAction.documentType(
    super.documents, {
    required this.labelId,
  }) : _labelName = 'document_type';

  BulkModifyLabelAction.storagePath(
    super.documents, {
    required this.labelId,
  }) : _labelName = 'storage_path';

  @override
  Map<String, dynamic> toJson() {
    return {
      'documents': documentIds.toList(),
      'method': 'set_$_labelName',
      'parameters': {
        _labelName: labelId,
      }
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

  BulkRotateAction(
    super.documents, {
    required this.degrees,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'documents': documentIds.toList(),
      'method': 'rotate',
      'parameters': {
        'degrees': degrees,
      }
    };
  }
}

class BulkSplitAction extends BulkAction {
  final String pages;
  final bool? deleteOriginals;

  BulkSplitAction(
    super.documents, {
    required this.pages,
    this.deleteOriginals,
  });

  @override
  Map<String, dynamic> toJson() {
    final parameters = <String, dynamic>{
      'pages': pages,
    };
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

  BulkDeletePagesAction(
    super.documents, {
    required this.pages,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'documents': documentIds.toList(),
      'method': 'delete_pages',
      'parameters': {
        'pages': pages.toList(),
      }
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
