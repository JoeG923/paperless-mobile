import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/features/landing/view/widgets/stats_card.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _FakeServerStatsApi extends Fake implements PaperlessServerStatsApi {
  @override
  Future<PaperlessServerStatisticsModel> getServerStatistics() async {
    return PaperlessServerStatisticsModel(
      documentsTotal: 1,
      documentsInInbox: 0,
      fileTypeCounts: [
        DocumentFileTypeCount(mimeType: 'application/xml', count: 1),
      ],
    );
  }
}

void main() {
  testWidgets('StatsCard renders unknown MIME types without crashing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      Provider<PaperlessServerStatsApi>.value(
        value: _FakeServerStatsApi(),
        child: MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: const Scaffold(body: StatsCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('XML'), findsOneWidget);
  });
}
