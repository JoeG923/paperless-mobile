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
        'parameters': {
          'degrees': 90,
        },
      });
    });

    test('BulkSplitAction toJson', () {
      final action = BulkSplitAction([7], pages: '1,2-3', deleteOriginals: true);
      expect(action.toJson(), {
        'documents': [7],
        'method': 'split',
        'parameters': {
          'pages': '1,2-3',
          'delete_originals': true,
        },
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
  });
}
