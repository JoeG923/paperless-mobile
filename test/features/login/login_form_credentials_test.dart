import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_mobile/features/login/model/login_form_credentials.dart';

void main() {
  test('hasApiToken is true only when token is non-empty after trim', () {
    expect(LoginFormCredentials(apiToken: 'abc').hasApiToken, isTrue);
    expect(LoginFormCredentials(apiToken: '  abc  ').hasApiToken, isTrue);
    expect(LoginFormCredentials(apiToken: '').hasApiToken, isFalse);
    expect(LoginFormCredentials(apiToken: '   ').hasApiToken, isFalse);
    expect(LoginFormCredentials().hasApiToken, isFalse);
  });

  test('copyWith keeps and updates apiToken alongside existing fields', () {
    final original = LoginFormCredentials(
      username: 'alice',
      password: 'pw',
      mfaCode: '123456',
    );

    final updated = original.copyWith(apiToken: 'token-1');

    expect(updated.username, 'alice');
    expect(updated.password, 'pw');
    expect(updated.mfaCode, '123456');
    expect(updated.apiToken, 'token-1');
  });
}
