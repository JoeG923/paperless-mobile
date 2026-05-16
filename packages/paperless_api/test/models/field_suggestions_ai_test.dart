import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  group('FieldSuggestions', () {
    test(
      'parses storage path suggestions from classic suggestions payload',
      () {
        final suggestions = FieldSuggestions.fromJson({
          'correspondents': [1],
          'tags': [2, 3],
          'document_types': [4],
          'storage_paths': [5],
          'dates': ['2026-05-15'],
        });

        expect(suggestions.storagePaths, [5]);
        expect(suggestions.hasSuggestedStoragePaths, isTrue);
        expect(suggestions.suggestionsCount, 5);
      },
    );

    test('copyWith preserves document type and storage path suggestions', () {
      const suggestions = FieldSuggestions(
        documentTypes: [7],
        storagePaths: [9],
      );

      final updated = suggestions.copyWith(tags: [1]);

      expect(updated.tags, [1]);
      expect(updated.documentTypes, [7]);
      expect(updated.storagePaths, [9]);
    });
  });

  group('AiDocumentSuggestions', () {
    test('parses matched IDs and new label names from v3 AI suggestions', () {
      final suggestions = AiDocumentSuggestions.fromJson({
        'title': 'Quarterly utility bill',
        'correspondents': [1],
        'suggested_correspondents': ['Power Co'],
        'tags': [2],
        'suggested_tags': ['utilities'],
        'document_types': [3],
        'suggested_document_types': ['Statement'],
        'storage_paths': [4],
        'suggested_storage_paths': ['Bills/Utilities'],
        'dates': ['2026-05-15'],
      }).forDocumentId(42);

      expect(suggestions.documentId, 42);
      expect(suggestions.title, 'Quarterly utility bill');
      expect(suggestions.correspondents, [1]);
      expect(suggestions.suggestedCorrespondents, ['Power Co']);
      expect(suggestions.tags, [2]);
      expect(suggestions.suggestedTags, ['utilities']);
      expect(suggestions.documentTypes, [3]);
      expect(suggestions.suggestedDocumentTypes, ['Statement']);
      expect(suggestions.storagePaths, [4]);
      expect(suggestions.suggestedStoragePaths, ['Bills/Utilities']);
      expect(suggestions.dates.single, DateTime(2026, 5, 15));
    });
  });
}
