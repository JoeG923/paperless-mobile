import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_mobile/features/documents/view/widgets/adaptive_documents_view.dart';

void main() {
  group('documentSelectionLookupOf', () {
    test(
      'is inactive and has no selected documents when selection is empty',
      () {
        final lookup = documentSelectionLookupOf(const []);

        expect(lookup.isSelectionActive, isFalse);
        expect(lookup.isSelected(1), isFalse);
      },
    );

    test('marks selected ids and keeps selection active', () {
      final lookup = documentSelectionLookupOf(const [5, 9, 12]);

      expect(lookup.isSelectionActive, isTrue);
      expect(lookup.isSelected(5), isTrue);
      expect(lookup.isSelected(9), isTrue);
      expect(lookup.isSelected(12), isTrue);
      expect(lookup.isSelected(4), isFalse);
    });

    test('duplicate ids still behave like a single selected id', () {
      final lookup = documentSelectionLookupOf(const [8, 8, 8]);

      expect(lookup.isSelectionActive, isTrue);
      expect(lookup.isSelected(8), isTrue);
      expect(lookup.isSelected(7), isFalse);
    });
  });
}
