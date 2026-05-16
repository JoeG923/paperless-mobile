import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:local_auth/local_auth.dart';
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

const _baseUrl = String.fromEnvironment(
  'E2E_PAPERLESS_BASE_URL',
  defaultValue: 'http://10.0.2.2:18000',
);
const _username = String.fromEnvironment(
  'E2E_PAPERLESS_USERNAME',
  defaultValue: 'e2e',
);
const _password = String.fromEnvironment(
  'E2E_PAPERLESS_PASSWORD',
  defaultValue: 'e2e-pass-123',
);
const _expectedApiVersion = String.fromEnvironment(
  'E2E_EXPECTED_API_VERSION',
  defaultValue: '',
);

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logs into a real paperless server and opens the app shell', (
    tester,
  ) async {
    await initializeDefaultParameters();
    final tempRoot = await getTemporaryDirectory();
    final hiveDirectory = await Directory(
      '${tempRoot.path}/paperless_real_login_${DateTime.now().microsecondsSinceEpoch}',
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
    final connectivityStatusService = ConnectivityStatusServiceImpl(
      Connectivity(),
    );
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
      _baseUrl,
    );
    await tester.tap(find.byKey(TestKeys.login.continueButton));
    await _pumpUntilFound(tester, find.byKey(TestKeys.login.usernameFormField));

    await tester.enterText(
      find.byKey(TestKeys.login.usernameFormField),
      _username,
    );
    await tester.enterText(
      find.byKey(TestKeys.login.passwordFormField),
      _password,
    );
    await tester.tap(find.byKey(TestKeys.login.loginButton));
    await _pumpUntilFound(tester, find.text('Documents'));

    final account = Hive.localUserAccountBox.get('$_username@$_baseUrl');
    expect(account, isNotNull);
    if (_expectedApiVersion.isNotEmpty) {
      final expectedApiVersion = int.parse(_expectedApiVersion);
      expect(account!.serverApiVersion, expectedApiVersion);
      expect(account.apiVersion, expectedApiVersion);
    }
  });
}
