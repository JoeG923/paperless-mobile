import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_mobile/core/security/auth_header_configuration.dart';
import 'package:paperless_mobile/core/security/session_manager_impl.dart';

void main() {
  test('uses Token authorization header by default', () {
    final manager = SessionManagerImpl();

    manager.updateSettings(authToken: 'abc123');

    expect(
      manager.client.options.headers[HttpHeaders.authorizationHeader],
      'Token abc123',
    );
  });

  test('supports custom auth header without prefix', () {
    final manager = SessionManagerImpl();

    manager.updateSettings(
      authHeaderConfiguration: const AuthHeaderConfiguration(
        headerName: 'x-api-key',
        valuePrefix: null,
      ),
      authToken: 'abc123',
    );

    expect(
      manager.client.options.headers[HttpHeaders.authorizationHeader],
      null,
    );
    expect(manager.client.options.headers['x-api-key'], 'abc123');
  });

  test('switching auth header configuration removes previous header key', () {
    final manager = SessionManagerImpl();
    manager.updateSettings(
      authHeaderConfiguration: const AuthHeaderConfiguration(
        headerName: 'x-api-key',
        valuePrefix: null,
      ),
      authToken: 'abc123',
    );

    manager.updateSettings(
      authHeaderConfiguration: const AuthHeaderConfiguration.bearer(),
      authToken: 'xyz789',
    );

    expect(manager.client.options.headers['x-api-key'], null);
    expect(
      manager.client.options.headers[HttpHeaders.authorizationHeader],
      'Bearer xyz789',
    );
  });

  test('resetSettings clears custom header and restores default behavior', () {
    final manager = SessionManagerImpl();
    manager.updateSettings(
      authHeaderConfiguration: const AuthHeaderConfiguration(
        headerName: 'x-api-key',
        valuePrefix: null,
      ),
      authToken: 'abc123',
    );

    manager.resetSettings();
    manager.updateSettings(authToken: 'fresh-token');

    expect(manager.client.options.headers['x-api-key'], null);
    expect(
      manager.client.options.headers[HttpHeaders.authorizationHeader],
      'Token fresh-token',
    );
  });

  test('invalid custom header name falls back to authorization header', () {
    final manager = SessionManagerImpl();
    manager.updateSettings(
      authHeaderConfiguration: const AuthHeaderConfiguration(
        headerName: 'x custom',
        valuePrefix: null,
      ),
      authToken: 'abc123',
    );

    expect(manager.client.options.headers['x custom'], null);
    expect(
      manager.client.options.headers[HttpHeaders.authorizationHeader],
      'Token abc123',
    );
  });

  test(
    'sanitizes control characters from auth token before setting header',
    () {
      final manager = SessionManagerImpl();

      manager.updateSettings(authToken: 'abc\u0000\r\n123');

      expect(
        manager.client.options.headers[HttpHeaders.authorizationHeader],
        'Token abc123',
      );
    },
  );
}
