import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/mockito.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/hive/hive_extensions.dart';
import 'package:paperless_mobile/core/database/hive/hive_initialization.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';
import 'package:paperless_mobile/core/security/session_manager.dart';
import 'package:paperless_mobile/core/security/session_manager_impl.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/login/cubit/authentication_cubit.dart';
import 'package:paperless_mobile/features/login/services/authentication_service.dart';
import 'package:paperless_mobile/features/notifications/services/local_notification_service.dart';
import 'package:paperless_mobile/keys.dart';
import 'package:paperless_mobile/main.dart'
    show initializeDefaultParameters, AppEntrypoint;
import 'package:path_provider/path_provider.dart';

import 'src/mocks/mock_paperless_api.dart';
import 'src/mocks/mock_paperless_api.mocks.dart';

class MockLocalAuthService extends Mock implements LocalAuthenticationService {}

class MockLocalNotificationService extends Mock
    implements LocalNotificationService {}

class _ApiVersionAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        PaperlessServerInformationModel.apiVersionHeader: ['10'],
      },
    );
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (predicate()) {
      return;
    }
  }
  throw TestFailure('Timed out waiting for condition');
}

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const locale = Locale("en", "US");
  const testServerUrl = 'https://example.com';
  const testUsername = 'user';
  const testPassword = 'pass';
  const testUser = UserModelV3(
    id: 1,
    username: testUsername,
    isStaff: true,
    isActive: true,
    isSuperuser: true,
    groups: [],
    userPermissions: [],
    inheritedPermissions: [],
  );

  late ConnectivityStatusServiceMock connectivityStatusService;
  late MockPaperlessApiFactory paperlessApiFactory;
  late AuthenticationCubit authenticationCubit;
  late LocalNotificationService localNotificationService;
  late SessionManager sessionManager;
  late Directory hiveDirectory;
  final localAuthService = MockLocalAuthService();

  provideDummy<UserModel>(testUser);

  setUp(() async {
    connectivityStatusService = ConnectivityStatusServiceMock(true);
    paperlessApiFactory = MockPaperlessApiFactory();
    sessionManager = SessionManagerImpl()
      ..client.httpClientAdapter = _ApiVersionAdapter();
    localNotificationService = MockLocalNotificationService();
    final tempRoot = await getTemporaryDirectory();
    hiveDirectory = await Directory(
      '${tempRoot.path}/paperless_login_e2e_${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);

    authenticationCubit = AuthenticationCubit(
      localAuthService,
      paperlessApiFactory,
      sessionManager,
      connectivityStatusService,
      localNotificationService,
    );
    await initHive(hiveDirectory, locale.toString());
    HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory: HydratedStorageDirectory(hiveDirectory.path),
    );
  });

  tearDown(() async {
    await Hive.close();
    if (hiveDirectory.existsSync()) {
      await hiveDirectory.delete(recursive: true);
    }
  });
  testWidgets(
    'A user shall be successfully logged in when providing correct credentials.',
    (tester) async {
      // Reset data to initial state with given [locale].
      await Hive.globalSettingsBox.setValue(
        GlobalSettings(
          preferredLocaleSubtag: locale.toString(),
          loggedInUserId: null,
        ),
      );
      when(
        paperlessApiFactory.authenticationApi.login(
          username: testUsername,
          password: testPassword,
        ),
      ).thenAnswer((_) async => "token");
      when(
        paperlessApiFactory.userApi.findCurrentUser(),
      ).thenAnswer((_) async => testUser);
      when(paperlessApiFactory.serverStatsApi.getUiSettings()).thenAnswer(
        (_) async => PaperlessUiSettingsModel(
          displayName: 'Paperless',
          settings: const {'ai_enabled': false},
        ),
      );
      when(
        (paperlessApiFactory.documentApi as MockPaperlessDocumentsApi).findAll(
          any,
        ),
      ).thenAnswer(
        (_) async =>
            const PagedSearchResult<DocumentModel>(count: 0, results: []),
      );

      await initializeDefaultParameters();

      await tester.pumpWidget(
        AppEntrypoint(
          apiFactory: paperlessApiFactory,
          authenticationCubit: authenticationCubit,
          connectivityStatusService: connectivityStatusService,
          localNotificationService: localNotificationService,
          localAuthService: localAuthService,
          sessionManager: sessionManager,
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      });
      await tester.binding.waitUntilFirstFrameRasterized;
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(TestKeys.login.serverAddressFormField),
        testServerUrl,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(TestKeys.login.continueButton));

      await _pumpUntilFound(
        tester,
        find.byKey(TestKeys.login.usernameFormField),
      );

      await tester.enterText(
        find.byKey(TestKeys.login.usernameFormField),
        testUsername,
      );
      await tester.enterText(
        find.byKey(TestKeys.login.passwordFormField),
        testPassword,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(TestKeys.login.loginButton));
      await _pumpUntil(
        tester,
        () => authenticationCubit.state is AuthenticatedState,
      );

      expect(
        Hive.globalSettingsBox.getValue()?.loggedInUserId,
        '$testUsername@$testServerUrl',
      );
    },
  );

  testWidgets(
    'MFA login clears rejected codes and accepts a fresh valid code.',
    (tester) async {
      await Hive.globalSettingsBox.setValue(
        GlobalSettings(
          preferredLocaleSubtag: locale.toString(),
          loggedInUserId: null,
        ),
      );
      when(
        paperlessApiFactory.authenticationApi.login(
          username: testUsername,
          password: testPassword,
          code: '000000',
        ),
      ).thenThrow(
        PaperlessFormValidationException({
          'non_field_errors': 'Invalid MFA code',
        }),
      );
      when(
        paperlessApiFactory.authenticationApi.login(
          username: testUsername,
          password: testPassword,
          code: '123456',
        ),
      ).thenAnswer((_) async => "token");
      when(
        paperlessApiFactory.userApi.findCurrentUser(),
      ).thenAnswer((_) async => testUser);
      when(paperlessApiFactory.serverStatsApi.getUiSettings()).thenAnswer(
        (_) async => PaperlessUiSettingsModel(
          displayName: 'Paperless',
          settings: const {'ai_enabled': false},
        ),
      );
      when(
        (paperlessApiFactory.documentApi as MockPaperlessDocumentsApi).findAll(
          any,
        ),
      ).thenAnswer(
        (_) async =>
            const PagedSearchResult<DocumentModel>(count: 0, results: []),
      );

      await initializeDefaultParameters();

      await tester.pumpWidget(
        AppEntrypoint(
          apiFactory: paperlessApiFactory,
          authenticationCubit: authenticationCubit,
          connectivityStatusService: connectivityStatusService,
          localNotificationService: localNotificationService,
          localAuthService: localAuthService,
          sessionManager: sessionManager,
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      });
      await tester.binding.waitUntilFirstFrameRasterized;
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(TestKeys.login.serverAddressFormField),
        testServerUrl,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TestKeys.login.continueButton));
      await _pumpUntilFound(
        tester,
        find.byKey(TestKeys.login.usernameFormField),
      );

      await tester.enterText(
        find.byKey(TestKeys.login.usernameFormField),
        testUsername,
      );
      await tester.enterText(
        find.byKey(TestKeys.login.passwordFormField),
        testPassword,
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-mfa-code')),
        '000000',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(TestKeys.login.loginButton));
      await _pumpUntil(
        tester,
        () =>
            authenticationCubit.state is AuthenticationErrorState ||
            find.byKey(TestKeys.login.loginButton).evaluate().isNotEmpty,
      );
      await _pumpUntilFound(tester, find.byKey(TestKeys.login.loginButton));

      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('login-mfa-code')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        isEmpty,
      );

      await tester.enterText(
        find.byKey(const ValueKey('login-mfa-code')),
        '123456',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TestKeys.login.loginButton));
      await _pumpUntil(
        tester,
        () => authenticationCubit.state is AuthenticatedState,
      );

      verify(
        paperlessApiFactory.authenticationApi.login(
          username: testUsername,
          password: testPassword,
          code: '000000',
        ),
      ).called(1);
      verify(
        paperlessApiFactory.authenticationApi.login(
          username: testUsername,
          password: testPassword,
          code: '123456',
        ),
      ).called(1);
      expect(
        Hive.globalSettingsBox.getValue()?.loggedInUserId,
        '$testUsername@$testServerUrl',
      );
    },
  );
}
