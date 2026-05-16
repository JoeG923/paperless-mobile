import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_mobile/features/login/model/login_form_credentials.dart';
import 'package:paperless_mobile/features/login/view/widgets/form_fields/user_credentials_form_field.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

void main() {
  testWidgets('shows password and MFA fields by default', (tester) async {
    final formKey = GlobalKey<FormBuilderState>();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: FormBuilder(
            key: formKey,
            child: UserCredentialsFormField(formKey: formKey),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('login-password')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-mfa-code')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-api-token')), findsNothing);
  });

  testWidgets('switching to API token mode swaps credential fields', (
    tester,
  ) async {
    final formKey = GlobalKey<FormBuilderState>();
    final l10n = await S.delegate.load(const Locale('en'));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: FormBuilder(
            key: formKey,
            child: UserCredentialsFormField(formKey: formKey),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Use API token instead of password'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('login-api-token')), findsOneWidget);
    expect(find.text(l10n.apiTokenRemoteUserHint), findsOneWidget);
    expect(find.byKey(const ValueKey('login-password')), findsNothing);
    expect(find.byKey(const ValueKey('login-mfa-code')), findsNothing);
  });

  testWidgets('API token input is written to form credentials value', (
    tester,
  ) async {
    final formKey = GlobalKey<FormBuilderState>();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: FormBuilder(
            key: formKey,
            child: UserCredentialsFormField(formKey: formKey),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Use API token instead of password'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('login-api-token')),
        matching: find.byType(EditableText),
      ),
      'token-123',
    );
    await tester.pump();

    final credentials =
        formKey
                .currentState!
                .fields[UserCredentialsFormField.fkCredentials]!
                .value
            as LoginFormCredentials?;
    expect(credentials, isNotNull);
    expect(credentials!.apiToken, 'token-123');
    expect(credentials.hasApiToken, isTrue);
  });

  testWidgets('MFA input is written to form credentials value', (tester) async {
    final formKey = GlobalKey<FormBuilderState>();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: FormBuilder(
            key: formKey,
            child: UserCredentialsFormField(formKey: formKey),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('login-username')),
      'alice',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('login-password')),
        matching: find.byType(EditableText),
      ),
      'password',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-mfa-code')),
      '123456',
    );
    await tester.pump();

    final credentials =
        formKey
                .currentState!
                .fields[UserCredentialsFormField.fkCredentials]!
                .value
            as LoginFormCredentials?;
    expect(credentials, isNotNull);
    expect(credentials!.username, 'alice');
    expect(credentials.password, 'password');
    expect(credentials.mfaCode, '123456');
  });
}
