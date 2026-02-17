import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_mobile/features/login/view/widgets/form_fields/server_address_form_field.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

void main() {
  testWidgets('shows localized hint text for server address', (tester) async {
    final l10n = await S.delegate.load(const Locale('en'));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: FormBuilder(child: const ServerAddressFormField()),
        ),
      ),
    );

    expect(find.text(l10n.serverAddressHint), findsOneWidget);
  });
}
