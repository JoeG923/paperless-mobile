import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_mobile/core/security/auth_token_resolver.dart';

void main() {
  test('defaults to Token authorization when no scheme is provided', () {
    final resolved = resolveAuthToken('abc123');

    expect(resolved.token, 'abc123');
    expect(resolved.authHeaderConfiguration.headerName, 'authorization');
    expect(resolved.authHeaderConfiguration.valuePrefix, 'Token');
  });

  test('parses Bearer tokens', () {
    final resolved = resolveAuthToken('Bearer jwt-token');

    expect(resolved.token, 'jwt-token');
    expect(resolved.authHeaderConfiguration.headerName, 'authorization');
    expect(resolved.authHeaderConfiguration.valuePrefix, 'Bearer');
  });

  test('parses auth schemes case-insensitively', () {
    final resolved = resolveAuthToken('bEaReR jwt-token');

    expect(resolved.token, 'jwt-token');
    expect(resolved.authHeaderConfiguration.headerName, 'authorization');
    expect(resolved.authHeaderConfiguration.valuePrefix, 'Bearer');
  });

  test('parses x-api-key tokens from prefix format', () {
    final resolved = resolveAuthToken('X-API-KEY key-123');

    expect(resolved.token, 'key-123');
    expect(resolved.authHeaderConfiguration.headerName, 'x-api-key');
    expect(resolved.authHeaderConfiguration.valuePrefix, isNull);
  });

  test('parses explicit custom header syntax', () {
    final resolved = resolveAuthToken('x-custom-header: secret-token');

    expect(resolved.token, 'secret-token');
    expect(resolved.authHeaderConfiguration.headerName, 'x-custom-header');
    expect(resolved.authHeaderConfiguration.valuePrefix, isNull);
  });

  test('sanitizes control characters in parsed token values', () {
    final resolved = resolveAuthToken('Bearer abc\u0000def');

    expect(resolved.token, 'abcdef');
    expect(resolved.authHeaderConfiguration.headerName, 'authorization');
    expect(resolved.authHeaderConfiguration.valuePrefix, 'Bearer');
  });

  test(
    'uses username fallback when explicit custom header has empty value',
    () {
      final resolved = resolveAuthToken(
        'x-remote-user:',
        usernameFallback: 'alice',
      );

      expect(resolved.token, 'alice');
      expect(resolved.authHeaderConfiguration.headerName, 'x-remote-user');
      expect(resolved.authHeaderConfiguration.valuePrefix, isNull);
    },
  );

  test('does not apply username fallback when explicit header has token', () {
    final resolved = resolveAuthToken(
      'x-remote-user: bob',
      usernameFallback: 'alice',
    );

    expect(resolved.token, 'bob');
    expect(resolved.authHeaderConfiguration.headerName, 'x-remote-user');
    expect(resolved.authHeaderConfiguration.valuePrefix, isNull);
  });

  test(
    'keeps explicit header when token is empty and no username fallback is provided',
    () {
      final resolved = resolveAuthToken('x-remote-user:');

      expect(resolved.token, isEmpty);
      expect(resolved.authHeaderConfiguration.headerName, 'x-remote-user');
      expect(resolved.authHeaderConfiguration.valuePrefix, isNull);
    },
  );

  test('falls back to standard auth for invalid explicit header names', () {
    final resolved = resolveAuthToken('x bad header: token');

    expect(resolved.token, 'x bad header: token');
    expect(resolved.authHeaderConfiguration.headerName, 'authorization');
    expect(resolved.authHeaderConfiguration.valuePrefix, 'Token');
  });
}
