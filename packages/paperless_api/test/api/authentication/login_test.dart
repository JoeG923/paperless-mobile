import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  group('AuthenticationApi with DioHttpErrorIncerceptor', () {
    late PaperlessAuthenticationApi authenticationApi;
    late DioAdapter mockAdapter;
    const token = "abcde";
    const accessToken = "access-token";
    const drfToken = "drf-token";
    const authToken = "auth-token";
    const fallbackEndpointToken = "fallback-endpoint-token";
    const secondFallbackEndpointToken = "second-fallback-endpoint-token";
    const mfaToken = "mfa-token";
    const invalidCredentialsServerMessage =
        "Unable to log in with provided credentials.";

    setUp(() {
      final dio = Dio()..interceptors.add(DioHttpErrorInterceptor());
      authenticationApi = PaperlessAuthenticationApiImpl(dio);
      mockAdapter = DioAdapter(dio: dio);
      // Valid credentials
      mockAdapter.onPost(
        "/api/token/",
        data: {"username": "username", "password": "password"},
        (server) => server.reply(200, {"token": token}),
      );
      // MFA credentials
      mockAdapter.onPost(
        "/api/token/",
        data: {"username": "mfaUser", "password": "password", "code": "123456"},
        (server) => server.reply(200, {"token": mfaToken}),
      );
      // Alternate token response shape used by some auth stacks
      mockAdapter.onPost(
        "/api/token/",
        data: {"username": "accessUser", "password": "password"},
        (server) => server.reply(200, {"access": accessToken}),
      );
      // DRF-style token key response
      mockAdapter.onPost(
        "/api/token/",
        data: {"username": "drfUser", "password": "password"},
        (server) => server.reply(200, {"key": drfToken}),
      );
      // Legacy token key response
      mockAdapter.onPost(
        "/api/token/",
        data: {"username": "legacyUser", "password": "password"},
        (server) => server.reply(200, {"auth_token": authToken}),
      );
      // Fallback token endpoint path
      mockAdapter.onPost(
        "/api/token/",
        data: {"username": "fallbackUser", "password": "password"},
        (server) => server.reply(404, {"detail": "Not found"}),
      );
      mockAdapter.onPost(
        "/api/token",
        data: {"username": "fallbackUser", "password": "password"},
        (server) => server.reply(200, {"token": fallbackEndpointToken}),
      );
      // Fallback through /api/auth/token/ when previous endpoints are not allowed
      mockAdapter.onPost(
        "/api/token/",
        data: {"username": "fallbackUser405", "password": "password"},
        (server) => server.reply(405, {"detail": "Method not allowed"}),
      );
      mockAdapter.onPost(
        "/api/token",
        data: {"username": "fallbackUser405", "password": "password"},
        (server) => server.reply(405, {"detail": "Method not allowed"}),
      );
      mockAdapter.onPost(
        "/api/auth/token/",
        data: {"username": "fallbackUser405", "password": "password"},
        (server) => server.reply(200, {"token": secondFallbackEndpointToken}),
      );
      // Invalid credentials
      mockAdapter.onPost(
        "/api/token/",
        data: {"username": "wrongUsername", "password": "wrongPassword"},
        (server) => server.reply(400, {
          "non_field_errors": [invalidCredentialsServerMessage],
        }),
      );
    });

    // tearDown(() {});
    test(
      'should return a valid token when logging in with valid credentials',
      () {
        expect(
          authenticationApi.login(username: "username", password: "password"),
          completion(token),
        );
      },
    );

    test('should throw a PaperlessFormValidationException containing a reason '
        'when logging in with invalid credentials', () {
      expect(
        authenticationApi.login(
          username: "wrongUsername",
          password: "wrongPassword",
        ),
        throwsA(
          isA<PaperlessFormValidationException>().having(
            (e) => e.unspecificErrorMessage(),
            "non-field specific error message",
            equals(invalidCredentialsServerMessage),
          ),
        ),
      );
    });

    test('should include MFA code when provided', () {
      expect(
        authenticationApi.login(
          username: "mfaUser",
          password: "password",
          code: "123456",
        ),
        completion(mfaToken),
      );
    });

    test('should resolve token from access key when token key is missing', () {
      expect(
        authenticationApi.login(username: "accessUser", password: "password"),
        completion(accessToken),
      );
    });

    test(
      'should resolve token from key field when token and access are missing',
      () {
        expect(
          authenticationApi.login(username: "drfUser", password: "password"),
          completion(drfToken),
        );
      },
    );

    test('should resolve token from auth_token field', () {
      expect(
        authenticationApi.login(username: "legacyUser", password: "password"),
        completion(authToken),
      );
    });

    test('should fallback to alternate token endpoint paths on 404', () {
      expect(
        authenticationApi.login(username: "fallbackUser", password: "password"),
        completion(fallbackEndpointToken),
      );
    });

    test('should fallback to third token endpoint path on 405 responses', () {
      expect(
        authenticationApi.login(
          username: "fallbackUser405",
          password: "password",
        ),
        completion(secondFallbackEndpointToken),
      );
    });

    test('should return an error when logging in with invalid credentials', () {
      expect(
        authenticationApi.login(
          username: "wrongUsername",
          password: "wrongPassword",
        ),
        throwsA(
          isA<PaperlessFormValidationException>().having(
            (e) => e.unspecificErrorMessage(),
            "non-field specific error message",
            equals(invalidCredentialsServerMessage),
          ),
        ),
      );
    });
  });
}
