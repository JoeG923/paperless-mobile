import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/hive/hive_initialization.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/login/model/client_certificate.dart';
import 'package:paperless_mobile/features/login/model/login_form_credentials.dart';
import 'package:paperless_mobile/features/login/view/add_account_page.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/keys.dart';
import 'package:provider/provider.dart';

void main() {
  late Directory hiveDir;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp(
      'paperless-mobile-login-test-',
    );
    await initHive(hiveDir, 'en_US');
  });

  tearDown(() async {
    await Hive.close();
    if (hiveDir.existsSync()) {
      await hiveDir.delete(recursive: true);
    }
  });

  testWidgets('login page does not overflow above system navigation controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            padding: EdgeInsets.only(bottom: 48),
          ),
          child: AddAccountPage(
            titleText: 'Connect',
            submitText: 'Sign in',
            versionOverride: '4.0.0',
            onSubmit:
                (
                  BuildContext context,
                  LoginFormCredentials credentials,
                  String serverUrl,
                  ClientCertificate? clientCertificate,
                ) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('submit sends MFA code once and clears it from the form', (
    tester,
  ) async {
    LoginFormCredentials? submittedCredentials;
    String? submittedServerUrl;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Provider<ConnectivityStatusService>.value(
          value: ConnectivityStatusServiceMock(true),
          child: AddAccountPage(
            titleText: 'Connect',
            submitText: 'Sign in',
            versionOverride: '4.0.0',
            onSubmit:
                (
                  BuildContext context,
                  LoginFormCredentials credentials,
                  String serverUrl,
                  ClientCertificate? clientCertificate,
                ) {
                  submittedCredentials = credentials;
                  submittedServerUrl = serverUrl;
                },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(TestKeys.login.serverAddressFormField),
      'https://paperless.example.com',
    );
    await tester.tap(find.byKey(TestKeys.login.continueButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(TestKeys.login.usernameFormField),
      'alice',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(TestKeys.login.passwordFormField),
        matching: find.byType(EditableText),
      ),
      'password',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-mfa-code')),
      '123456',
    );
    await tester.ensureVisible(find.byKey(TestKeys.login.loginButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestKeys.login.loginButton));
    await tester.pump();

    expect(submittedServerUrl, 'https://paperless.example.com');
    expect(submittedCredentials?.username, 'alice');
    expect(submittedCredentials?.password, 'password');
    expect(submittedCredentials?.mfaCode, '123456');
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
  });

  testWidgets('MFA login flow clears bad code and submits fresh code', (
    tester,
  ) async {
    final submittedCodes = <String?>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Provider<ConnectivityStatusService>.value(
          value: ConnectivityStatusServiceMock(true),
          child: AddAccountPage(
            titleText: 'Connect',
            submitText: 'Sign in',
            versionOverride: '4.0.0',
            onSubmit:
                (
                  BuildContext context,
                  LoginFormCredentials credentials,
                  String serverUrl,
                  ClientCertificate? clientCertificate,
                ) {
                  submittedCodes.add(credentials.mfaCode);
                  if (credentials.mfaCode == '000000') {
                    throw PaperlessFormValidationException({
                      'non_field_errors': 'Invalid MFA code',
                    });
                  }
                },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(TestKeys.login.serverAddressFormField),
      'https://paperless.example.com',
    );
    await tester.tap(find.byKey(TestKeys.login.continueButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(TestKeys.login.usernameFormField),
      'alice',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(TestKeys.login.passwordFormField),
        matching: find.byType(EditableText),
      ),
      'password',
    );

    await tester.enterText(
      find.byKey(const ValueKey('login-mfa-code')),
      '000000',
    );
    await tester.ensureVisible(find.byKey(TestKeys.login.loginButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestKeys.login.loginButton));
    await tester.pump();

    expect(submittedCodes, ['000000']);
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
    await tester.ensureVisible(find.byKey(TestKeys.login.loginButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestKeys.login.loginButton));
    await tester.pump();

    expect(submittedCodes, ['000000', '123456']);
  });
}
