import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:paperless_mobile/features/documents/view/pages/documents_page.dart';
import 'package:paperless_mobile/features/documents/view/widgets/saved_views/saved_view_changed_dialog.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';

void main() {
  group('shouldPromptSavedViewReset', () {
    test('returns false when active saved view matches current filter', () {
      final filter = const DocumentFilter(
        correspondent: SetIdQueryParameter(id: 1),
        query: TextQuery.title('Annual Report'),
      );
      final activeView = SavedView.fromDocumentFilter(
        filter,
        name: 'Annual Report',
        showInSidebar: false,
        showOnDashboard: false,
      );

      final result = shouldPromptSavedViewReset(
        currentFilter: filter,
        activeSavedView: activeView,
      );

      expect(result, isFalse);
    });

    test('returns true when active saved view differs from current filter', () {
      final savedViewFilter = const DocumentFilter(
        correspondent: SetIdQueryParameter(id: 1),
      );
      final currentFilter = savedViewFilter.copyWith(
        documentType: const SetIdQueryParameter(id: 4),
      );
      final activeView = SavedView.fromDocumentFilter(
        savedViewFilter,
        name: 'Correspondent Reports',
        showInSidebar: false,
        showOnDashboard: false,
      );

      final result = shouldPromptSavedViewReset(
        currentFilter: currentFilter,
        activeSavedView: activeView,
      );

      expect(result, isTrue);
    });

    test('returns false when no active saved view exists', () {
      final result = shouldPromptSavedViewReset(
        currentFilter: const DocumentFilter(),
        activeSavedView: null,
      );

      expect(result, isFalse);
    });
  });

  testWidgets('SavedViewChangedDialog returns true when user confirms reset', (
    WidgetTester tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => const SavedViewChangedDialog(),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset filter'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('SavedViewChangedDialog returns false when user cancels', (
    WidgetTester tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => const SavedViewChangedDialog(),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
