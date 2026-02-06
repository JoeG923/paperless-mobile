import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_mobile/routing/routes/login_route.dart';

void main() {
  test('LoginRoute location never serializes a password query parameter', () {
    const route = LoginRoute(
      serverUrl: 'https://paperless.example.com',
      username: 'alice',
    );

    final location = route.location;
    expect(location, contains('server-url='));
    expect(location, contains('username='));
    expect(location, isNot(contains('password=')));
  });
}
