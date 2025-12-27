import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  group('AuthenticationApi with DioHttpErrorIncerceptor', () {
    late PaperlessAuthenticationApi authenticationApi;
    late DioAdapter mockAdapter;
    const token = "abcde";
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
        data: {
          "username": "username",
          "password": "password",
        },
        (server) => server.reply(200, {"token": token}),
      );
      // MFA credentials
      mockAdapter.onPost(
        "/api/token/",
        data: {
          "username": "mfaUser",
          "password": "password",
          "code": "123456",
        },
        (server) => server.reply(200, {"token": mfaToken}),
      );
      // Invalid credentials
      mockAdapter.onPost(
        "/api/token/",
        data: {
          "username": "wrongUsername",
          "password": "wrongPassword",
        },
        (server) => server.reply(400, {
          "non_field_errors": [invalidCredentialsServerMessage]
        }),
      );
    });

    // tearDown(() {});
    test(
      'should return a valid token when logging in with valid credentials',
      () {
        expect(
          authenticationApi.login(
            username: "username",
            password: "password",
          ),
          completion(token),
        );
      },
    );

    test(
      'should throw a PaperlessFormValidationException containing a reason '
      'when logging in with invalid credentials',
      () {
        expect(
          authenticationApi.login(
            username: "wrongUsername",
            password: "wrongPassword",
          ),
          throwsA(isA<PaperlessFormValidationException>().having(
            (e) => e.unspecificErrorMessage(),
            "non-field specific error message",
            equals(invalidCredentialsServerMessage),
          )),
        );
      },
    );

    test(
      'should include MFA code when provided',
      () {
        expect(
          authenticationApi.login(
            username: "mfaUser",
            password: "password",
            code: "123456",
          ),
          completion(mfaToken),
        );
      },
    );

    test(
      'should return an error when logging in with invalid credentials',
      () {
        expect(
          authenticationApi.login(
            username: "wrongUsername",
            password: "wrongPassword",
          ),
          throwsA(isA<PaperlessFormValidationException>().having(
            (e) => e.unspecificErrorMessage(),
            "non-field specific error message",
            equals(invalidCredentialsServerMessage),
          )),
        );
      },
    );
  });
}
