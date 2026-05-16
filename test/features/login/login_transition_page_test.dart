import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_mobile/features/login/view/widgets/login_transition_page.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

void main() {
  testWidgets('app logs link stays above system navigation safe area', (
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
          child: const LoginTransitionPage(text: 'Authenticating...'),
        ),
      ),
    );

    final logsButtonBottom = tester
        .getBottomLeft(find.widgetWithText(TextButton, 'App logs '))
        .dy;

    expect(logsButtonBottom, lessThanOrEqualTo(640 - 48));
  });
}
