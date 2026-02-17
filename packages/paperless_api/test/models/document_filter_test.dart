import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  test('DocumentFilter serializes custom_field_query parameter', () {
    const filter = DocumentFilter(
      customFieldQuery: '{"operator":"and","rules":[]}',
    );

    final query = filter.toQueryParameters();

    expect(query['custom_field_query'], '{"operator":"and","rules":[]}');
  });

  test('DocumentFilter.appliedFiltersCount includes customFieldQuery', () {
    const filter = DocumentFilter(
      customFieldQuery: '{"operator":"and","rules":[]}',
    );
    expect(filter.appliedFiltersCount, 1);
  });
}
