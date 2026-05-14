import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:paperless_mobile/core/widgets/error_report_page.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

void main() {
  testWidgets('Long description field uses the longDescription form key', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: ErrorReportPage(),
      ),
    );

    final fields = find.byType(FormBuilderTextField);
    expect(fields, findsNWidgets(2));

    final shortDescriptionField = tester.widget<FormBuilderTextField>(
      fields.at(0),
    );
    final longDescriptionField = tester.widget<FormBuilderTextField>(
      fields.at(1),
    );

    expect(shortDescriptionField.name, 'shortDescription');
    expect(longDescriptionField.name, 'longDescription');
  });
}
