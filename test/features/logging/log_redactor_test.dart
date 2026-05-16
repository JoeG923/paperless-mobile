import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:paperless_mobile/features/logging/data/formatted_printer.dart';
import 'package:paperless_mobile/features/logging/data/log_redactor.dart';
import 'package:paperless_mobile/features/logging/models/formatted_log_message.dart';

void main() {
  group('LogRedactor', () {
    test('redacts credential-shaped values from log text', () {
      final redacted =
          'Authorization: Token abcdefghijklmnop\n'
                  'x-api-key: key-secret\n'
                  '{"password":"hunter2","token":"token-secret"}\n'
                  'https://paperless.example/api?token=token-secret&ok=true'
              .redactForLogs();

      expect(redacted, isNot(contains('abcdefghijklmnop')));
      expect(redacted, isNot(contains('key-secret')));
      expect(redacted, isNot(contains('hunter2')));
      expect(redacted, isNot(contains('token-secret')));
      expect(redacted, contains('[REDACTED]'));
    });

    test('does not redact ordinary token words without secret values', () {
      expect(
        'Fetching bearer token from the server...'.redactForLogs(),
        'Fetching bearer token from the server...',
      );
      expect(
        'Bearer token successfully retrieved.'.redactForLogs(),
        'Bearer token successfully retrieved.',
      );
    });
  });

  group('FormattedPrinter', () {
    test('redacts messages, errors, and stack traces before output', () {
      final printer = FormattedPrinter();
      final lines = printer.log(
        LogEvent(
          Level.error,
          FormattedLogMessage(
            'Authorization: Token abcdefghijklmnop',
            className: 'Auth',
            methodName: 'login',
          ),
          error: 'password=hunter2',
          stackTrace: StackTrace.fromString(
            'Bearer abcdefghijklmnop\n'
            'token=token-secret',
          ),
        ),
      );
      final output = lines.join('\n');

      expect(output, isNot(contains('abcdefghijklmnop')));
      expect(output, isNot(contains('hunter2')));
      expect(output, isNot(contains('token-secret')));
      expect(output, contains('[REDACTED]'));
    });
  });
}
