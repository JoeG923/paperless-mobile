import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  group('BulkAction serialization', () {
    test('BulkReprocessAction toJson', () {
      final action = BulkReprocessAction([1, 2, 3]);
      expect(action.toJson(), {
        'documents': [1, 2, 3],
        'method': 'reprocess',
        'parameters': {},
      });
    });

    test('BulkRotateAction toJson', () {
      final action = BulkRotateAction([10], degrees: 90);
      expect(action.toJson(), {
        'documents': [10],
        'method': 'rotate',
        'parameters': {'degrees': 90},
      });
    });

    test('BulkSplitAction toJson', () {
      final action = BulkSplitAction(
        [7],
        pages: '1,2-3',
        deleteOriginals: true,
      );
      expect(action.toJson(), {
        'documents': [7],
        'method': 'split',
        'parameters': {'pages': '1,2-3', 'delete_originals': true},
      });
    });

    test('BulkDeletePagesAction toJson', () {
      final action = BulkDeletePagesAction([7], pages: [2, 3, 4]);
      expect(action.toJson(), {
        'documents': [7],
        'method': 'delete_pages',
        'parameters': {
          'pages': [2, 3, 4],
        },
      });
    });

    test('BulkMergeAction toJson', () {
      final action = BulkMergeAction(
        [4, 5],
        deleteOriginals: false,
        metadataDocumentId: 4,
        archiveFallback: true,
      );
      expect(action.toJson(), {
        'documents': [4, 5],
        'method': 'merge',
        'parameters': {
          'delete_originals': false,
          'metadata_document_id': 4,
          'archive_fallback': true,
        },
      });
    });

    test('BulkModifyCustomFieldsAction toJson (id list payload)', () {
      final action = BulkModifyCustomFieldsAction(
        [10, 11],
        addCustomFields: BulkCustomFieldPayload.ids([1, 2]),
        removeCustomFields: [3],
      );
      expect(action.toJson(), {
        'documents': [10, 11],
        'method': 'modify_custom_fields',
        'parameters': {
          'add_custom_fields': [1, 2],
          'remove_custom_fields': [3],
        },
      });
    });

    test('BulkModifyCustomFieldsAction toJson (value map payload)', () {
      final action = BulkModifyCustomFieldsAction(
        [12],
        addCustomFields: BulkCustomFieldPayload.values({7: 'foo'}),
        removeCustomFields: const [],
      );
      expect(action.toJson(), {
        'documents': [12],
        'method': 'modify_custom_fields',
        'parameters': {
          'add_custom_fields': {'7': 'foo'},
          'remove_custom_fields': <int>[],
        },
      });
    });

    test('BulkSetPermissionsAction toJson', () {
      final action = BulkSetPermissionsAction(
        [1],
        setPermissions: {
          'view': {
            'users': [1, 2],
            'groups': [3],
          },
          'change': {
            'users': [1],
            'groups': [],
          },
        },
        merge: true,
      );
      expect(action.toJson(), {
        'documents': [1],
        'method': 'set_permissions',
        'parameters': {
          'set_permissions': {
            'view': {
              'users': [1, 2],
              'groups': [3],
            },
            'change': {
              'users': [1],
              'groups': [],
            },
          },
          'merge': true,
        },
      });
    });

    test('BulkEditPdfAction toJson', () {
      final action = BulkEditPdfAction(
        [7],
        operations: const [
          {'page': 1, 'rotate': 90, 'doc': 0},
        ],
        updateDocument: false,
      );
      expect(action.toJson(), {
        'documents': [7],
        'method': 'edit_pdf',
        'parameters': {
          'operations': [
            {'page': 1, 'rotate': 90, 'doc': 0},
          ],
          'update_document': false,
          'include_metadata': true,
        },
      });
    });

    test('BulkRemovePasswordAction toJson', () {
      final action = BulkRemovePasswordAction([42], password: 'secret');
      expect(action.toJson(), {
        'documents': [42],
        'method': 'remove_password',
        'parameters': {'password': 'secret'},
      });
    });
  });
}
