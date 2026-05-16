import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mock_server/mock_server.dart';
import 'package:paperless_mobile/constants.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/hive/hive_extensions.dart';
import 'package:paperless_mobile/core/database/hive/hive_initialization.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';
import 'package:paperless_mobile/core/factory/paperless_api_factory_impl.dart';
import 'package:paperless_mobile/core/interceptor/language_header.interceptor.dart';
import 'package:paperless_mobile/core/security/session_manager_impl.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/login/cubit/authentication_cubit.dart';
import 'package:paperless_mobile/features/login/services/authentication_service.dart';
import 'package:paperless_mobile/features/notifications/services/local_notification_service.dart';
import 'package:paperless_mobile/keys.dart';
import 'package:paperless_mobile/main.dart'
    show AppEntrypoint, initializeDefaultParameters;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoOpLocalAuthenticationService extends LocalAuthenticationService {
  _NoOpLocalAuthenticationService() : super(LocalAuthentication());

  @override
  Future<bool> authenticateLocalUser(String localizedReason) async => true;
}

class _NoOpLocalNotificationService extends LocalNotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> cancelUserNotifications(String userId) async {}
}

var _defaultParametersInitialized = false;

Future<void> _ensureDefaultParametersInitialized() async {
  if (_defaultParametersInitialized) {
    return;
  }
  await initializeDefaultParameters();
  _defaultParametersInitialized = true;
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 60),
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

Future<_RunningApp> _pumpLoggedInApp(
  WidgetTester tester, {
  required bool aiEnabled,
  int apiVersion = 10,
}) async {
  final server = LocalMockApiServer(
    delayGenerator: const ZeroResponseDelayFactory(),
    apiVersion: apiVersion,
    aiEnabled: aiEnabled,
    useBuiltInFixturesOnly: true,
    port: 0,
  );
  await server.start();

  await _ensureDefaultParametersInitialized();
  final tempRoot = await getTemporaryDirectory();
  final hiveDirectory = await Directory(
    '${tempRoot.path}/paperless_ai_e2e_${DateTime.now().microsecondsSinceEpoch}',
  ).create(recursive: true);
  await initHive(hiveDirectory, 'en_US');
  await Hive.globalSettingsBox.setValue(
    GlobalSettings(preferredLocaleSubtag: 'en_US'),
  );

  final sharedPreferences = await SharedPreferences.getInstance();
  await sharedPreferences.setStringList('changelogSeenForBuilds', [
    packageInfo.buildNumber,
  ]);

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(hiveDirectory.path),
  );

  final sessionManager = SessionManagerImpl([
    LanguageHeaderInterceptor(() => 'en_US'),
  ]);
  final apiFactory = PaperlessApiFactoryImpl(sessionManager);
  final connectivityStatusService = ConnectivityStatusServiceMock(true);
  final localNotificationService = _NoOpLocalNotificationService();
  final localAuthService = _NoOpLocalAuthenticationService();
  final authenticationCubit = AuthenticationCubit(
    localAuthService,
    apiFactory,
    sessionManager,
    connectivityStatusService,
    localNotificationService,
  );

  await tester.pumpWidget(
    AppEntrypoint(
      apiFactory: apiFactory,
      authenticationCubit: authenticationCubit,
      connectivityStatusService: connectivityStatusService,
      localNotificationService: localNotificationService,
      localAuthService: localAuthService,
      sessionManager: sessionManager,
    ),
  );
  await _pumpUntilFound(
    tester,
    find.byKey(TestKeys.login.serverAddressFormField),
  );

  await tester.enterText(
    find.byKey(TestKeys.login.serverAddressFormField),
    server.serverUrl,
  );
  await tester.tap(find.byKey(TestKeys.login.continueButton));
  await _pumpUntilFound(tester, find.byKey(TestKeys.login.usernameFormField));

  await tester.enterText(find.byKey(TestKeys.login.usernameFormField), 'admin');
  await tester.enterText(find.byKey(TestKeys.login.passwordFormField), 'test');
  await tester.tap(find.byKey(TestKeys.login.loginButton));
  await _pumpUntilFound(tester, find.text('Documents'));

  return _RunningApp(server: server, hiveDirectory: hiveDirectory);
}

class _RunningApp {
  final LocalMockApiServer server;
  final Directory hiveDirectory;

  const _RunningApp({required this.server, required this.hiveDirectory});

  Future<void> close() async {
    await server.close();
    await Hive.close();
    if (hiveDirectory.existsSync()) {
      await hiveDirectory.delete(recursive: true);
    }
  }
}

Future<void> _disposeRunningApp(WidgetTester tester, _RunningApp app) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  await app.close();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AI enabled server exposes document chat from Home', (
    tester,
  ) async {
    final app = await _pumpLoggedInApp(tester, aiEnabled: true);
    addTearDown(() => _disposeRunningApp(tester, app));

    await _pumpUntilFound(tester, find.text('Ask'));
    await tester.tap(find.text('Ask'));
    await _pumpUntilFound(tester, find.text('Ask documents'));

    expect(find.text('All visible documents'), findsOneWidget);
    expect(
      find.textContaining('AI requests go to your paperless-ngx server'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Summarize my documents');
    await tester.tap(find.byIcon(Icons.send));
    await _pumpUntilFound(
      tester,
      find.text('Mock answer about your documents.'),
    );

    expect(find.text('References'), findsOneWidget);
    expect(find.text('No latin title'), findsOneWidget);
  });

  testWidgets('AI enabled server exposes document-scoped AI actions', (
    tester,
  ) async {
    final app = await _pumpLoggedInApp(tester, aiEnabled: true);
    addTearDown(() => _disposeRunningApp(tester, app));

    await tester.tap(find.byIcon(Icons.folder_rounded).last);
    await _pumpUntilFound(tester, find.text('No latin title'));
    await tester.tap(find.text('No latin title').first);
    await _pumpUntilFound(tester, find.text('AI'));

    await tester.tap(find.text('AI'));
    await _pumpUntilFound(tester, find.text('Ask this document'));
    expect(find.text('Improve metadata'), findsOneWidget);

    await tester.ensureVisible(find.text('Open chat'));
    await tester.tap(find.text('Open chat'));
    await _pumpUntilFound(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'What is this?');
    await tester.tap(find.byIcon(Icons.send));
    await _pumpUntilFound(
      tester,
      find.text('Mock answer about your documents.'),
    );
  });

  testWidgets('AI disabled server hides document chat entry points on Home', (
    tester,
  ) async {
    final app = await _pumpLoggedInApp(tester, aiEnabled: false);
    addTearDown(() => _disposeRunningApp(tester, app));

    await tester.pumpAndSettle();

    expect(find.text('Documents'), findsWidgets);
    expect(find.text('Ask'), findsNothing);
  });

  testWidgets('API 9 server hides AI entry points on Home', (tester) async {
    final app = await _pumpLoggedInApp(tester, apiVersion: 9, aiEnabled: true);
    addTearDown(() => _disposeRunningApp(tester, app));

    await tester.pumpAndSettle();

    expect(find.text('Documents'), findsWidgets);
    expect(find.text('Ask'), findsNothing);
  });
}
