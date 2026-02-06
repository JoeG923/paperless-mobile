import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_mobile/features/logging/utils/redaction_utils.dart';

void main() {
  test('redacts host for standard user id', () {
    expect(
      redactUserId('alice@https://paperless.example.com'),
      'alice@pa***om',
    );
  });

  test('handles very short hosts without throwing', () {
    expect(redactUserId('alice@https://a'), 'alice@a***');
  });

  test('returns unknown host for malformed server url', () {
    expect(redactUserId('alice@not a url'), 'alice@unknown');
  });

  test('returns unknown values for malformed user id input', () {
    expect(redactUserId('invalid'), 'unknown@unknown');
  });
}
