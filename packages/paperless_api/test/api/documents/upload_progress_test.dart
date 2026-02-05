import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/src/modules/documents_api/paperless_documents_api_impl.dart';

void main() {
  test('safeProgress returns 0.0 when total is zero', () {
    expect(safeProgress(10, 0), 0.0);
  });

  test('safeProgress returns fraction when total is positive', () {
    expect(safeProgress(5, 10), 0.5);
  });
}
