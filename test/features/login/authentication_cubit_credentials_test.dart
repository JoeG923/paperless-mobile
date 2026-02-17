import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/factory/paperless_api_factory.dart';
import 'package:paperless_mobile/core/security/auth_header_configuration.dart';
import 'package:paperless_mobile/core/security/session_manager.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/login/cubit/authentication_cubit.dart';
import 'package:paperless_mobile/features/login/model/client_certificate.dart';
import 'package:paperless_mobile/features/login/model/login_form_credentials.dart';
import 'package:paperless_mobile/features/login/services/authentication_service.dart';
import 'package:paperless_mobile/features/notifications/services/local_notification_service.dart';

class _FakeSessionManager extends ChangeNotifier implements SessionManager {
  @override
  final Dio client = Dio();

  @override
  void resetSettings() {}

  @override
  void updateSettings({
    String? baseUrl,
    String? authToken,
    ClientCertificate? clientCertificate,
    AuthHeaderConfiguration? authHeaderConfiguration,
  }) {}
}

class _FakeApiFactory implements PaperlessApiFactory {
  int createAuthenticationApiCalls = 0;

  @override
  PaperlessAuthenticationApi createAuthenticationApi(Dio dio) {
    createAuthenticationApiCalls++;
    throw UnimplementedError();
  }

  @override
  CustomFieldsApi createCustomFieldsApi(Dio dio, {required int apiVersion}) {
    throw UnimplementedError();
  }

  @override
  PaperlessDocumentsApi createDocumentsApi(Dio dio, {required int apiVersion}) {
    throw UnimplementedError();
  }

  @override
  PaperlessLabelsApi createLabelsApi(Dio dio, {required int apiVersion}) {
    throw UnimplementedError();
  }

  @override
  PaperlessSavedViewsApi createSavedViewsApi(
    Dio dio, {
    required int apiVersion,
  }) {
    throw UnimplementedError();
  }

  @override
  PaperlessServerStatsApi createServerStatsApi(
    Dio dio, {
    required int apiVersion,
  }) {
    throw UnimplementedError();
  }

  @override
  PaperlessTasksApi createTasksApi(Dio dio, {required int apiVersion}) {
    throw UnimplementedError();
  }

  @override
  PaperlessUserApi createUserApi(Dio dio, {required int apiVersion}) {
    throw UnimplementedError();
  }

  @override
  PaperlessGroupsApi createGroupsApi(Dio dio, {required int apiVersion}) {
    throw UnimplementedError();
  }
}

AuthenticationCubit _buildCubit(PaperlessApiFactory apiFactory) {
  return AuthenticationCubit(
    LocalAuthenticationService(LocalAuthentication()),
    apiFactory,
    _FakeSessionManager(),
    ConnectivityStatusServiceMock(true),
    LocalNotificationService(),
  );
}

void main() {
  test(
    'login throws ArgumentError when password and token are both missing',
    () async {
      final cubit = _buildCubit(_FakeApiFactory());

      await expectLater(
        () => cubit.login(
          credentials: LoginFormCredentials(username: 'alice'),
          serverUrl: 'https://paperless.example.com',
        ),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  test(
    'addAccount throws ArgumentError when password and token are missing',
    () async {
      final cubit = _buildCubit(_FakeApiFactory());

      await expectLater(
        () => cubit.addAccount(
          credentials: LoginFormCredentials(username: 'alice'),
          serverUrl: 'https://paperless.example.com',
          enableBiometricAuthentication: false,
          locale: 'en',
        ),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  test(
    'login with api token passes credential guard (no ArgumentError)',
    () async {
      final apiFactory = _FakeApiFactory();
      final cubit = _buildCubit(apiFactory);
      Object? error;

      try {
        await cubit.login(
          credentials: LoginFormCredentials(
            username: 'alice',
            apiToken: 'token-123',
          ),
          serverUrl: 'https://paperless.example.com',
        );
      } catch (e) {
        error = e;
      }

      expect(error, isNot(isA<ArgumentError>()));
      expect(apiFactory.createAuthenticationApiCalls, 0);
    },
  );

  test(
    'login with remote-user header shorthand passes credential guard',
    () async {
      final apiFactory = _FakeApiFactory();
      final cubit = _buildCubit(apiFactory);
      Object? error;

      try {
        await cubit.login(
          credentials: LoginFormCredentials(
            username: 'alice',
            apiToken: 'x-remote-user:',
          ),
          serverUrl: 'https://paperless.example.com',
        );
      } catch (e) {
        error = e;
      }

      expect(error, isNot(isA<ArgumentError>()));
      expect(apiFactory.createAuthenticationApiCalls, 0);
    },
  );
}
