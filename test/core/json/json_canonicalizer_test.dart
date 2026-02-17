import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_mobile/core/json/json_canonicalizer.dart';

void main() {
  test('canonicalizeJsonString returns null for empty input', () {
    expect(canonicalizeJsonString(null), isNull);
    expect(canonicalizeJsonString(''), isNull);
    expect(canonicalizeJsonString('   '), isNull);
  });

  test('canonicalizeJsonString normalizes object key order recursively', () {
    final canonical = canonicalizeJsonString(
      '{"z":1,"a":{"d":4,"b":2},"l":[{"y":2,"x":1}]}',
    );

    expect(canonical, '{"a":{"b":2,"d":4},"l":[{"x":1,"y":2}],"z":1}');
  });

  test(
    'canonicalizeJsonString returns trimmed original string on invalid json',
    () {
      expect(canonicalizeJsonString('  {"invalid"  '), '{"invalid"');
    },
  );
}
