import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  group('DocumentFilter API-version-aware search parameters', () {
    test('uses title_content for title and content search on API v9', () {
      final filter = DocumentFilter(
        query: const TextQuery.titleAndContent('invoice'),
      );

      final params = filter.toQueryParameters(apiVersion: 9);

      expect(params['title_content'], 'invoice');
      expect(params, isNot(contains('text')));
    });

    test('uses text for title and content search on API v10', () {
      final filter = DocumentFilter(
        query: const TextQuery.titleAndContent('invoice'),
      );

      final params = filter.toQueryParameters(apiVersion: 10);

      expect(params['text'], 'invoice');
      expect(params, isNot(contains('title_content')));
    });

    test('uses title_search for title-only search on API v10', () {
      final filter = DocumentFilter(query: const TextQuery.title('receipt'));

      final params = filter.toQueryParameters(apiVersion: 10);

      expect(params['title_search'], 'receipt');
      expect(params, isNot(contains('title__icontains')));
    });

    test('keeps advanced query unchanged on API v9 and v10', () {
      final filter = DocumentFilter(query: const TextQuery.extended('tag:tax'));

      expect(filter.toQueryParameters(apiVersion: 9)['query'], 'tag:tax');
      expect(filter.toQueryParameters(apiVersion: 10)['query'], 'tag:tax');
    });
  });
}
