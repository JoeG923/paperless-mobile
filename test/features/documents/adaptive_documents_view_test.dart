import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/documents/view/widgets/adaptive_documents_view.dart';
import 'package:paperless_mobile/features/documents/view/widgets/items/document_list_item.dart';
import 'package:paperless_mobile/features/settings/model/view_type.dart';
import 'package:provider/provider.dart';

class _FakeDocumentsApi extends Fake implements PaperlessDocumentsApi {
  @override
  String getThumbnailUrl(int docId) => 'https://example.invalid/$docId.png';
}

class _FakeLabelsApi extends Fake implements PaperlessLabelsApi {
  @override
  Future<List<Correspondent>> getCorrespondents([Iterable<int>? ids]) async =>
      const [];

  @override
  Future<List<DocumentType>> getDocumentTypes([Iterable<int>? ids]) async =>
      const [];

  @override
  Future<List<StoragePath>> getStoragePaths([Iterable<int>? ids]) async =>
      const [];

  @override
  Future<List<Tag>> getTags([Iterable<int>? ids]) async => const [];
}

DocumentModel _document() {
  final now = DateTime(2026, 1, 1);
  return DocumentModel(
    id: 1,
    title: 'List smoke document',
    content: 'Content',
    tags: const [],
    created: now,
    modified: now,
    added: now,
    documentType: null,
    correspondent: null,
  );
}

void main() {
  testWidgets('sliver list view renders document rows', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PaperlessDocumentsApi>.value(value: _FakeDocumentsApi()),
          Provider<ConnectivityStatusService>.value(
            value: ConnectivityStatusServiceMock(true),
          ),
          Provider<CacheManager>.value(value: DefaultCacheManager()),
          ChangeNotifierProvider<LabelRepository>(
            create: (_) => LabelRepository(_FakeLabelsApi()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAdaptiveDocumentsView(
                  documents: [_document()],
                  enableHeroAnimation: false,
                  hasLoaded: true,
                  isLabelClickable: true,
                  isLoading: false,
                  viewType: ViewType.list,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(DocumentListItem), findsOneWidget);
    expect(find.text('List smoke document'), findsOneWidget);
  });

  group('documentSelectionLookupOf', () {
    test(
      'is inactive and has no selected documents when selection is empty',
      () {
        final lookup = documentSelectionLookupOf(const []);

        expect(lookup.isSelectionActive, isFalse);
        expect(lookup.isSelected(1), isFalse);
      },
    );

    test('marks selected ids and keeps selection active', () {
      final lookup = documentSelectionLookupOf(const [5, 9, 12]);

      expect(lookup.isSelectionActive, isTrue);
      expect(lookup.isSelected(5), isTrue);
      expect(lookup.isSelected(9), isTrue);
      expect(lookup.isSelected(12), isTrue);
      expect(lookup.isSelected(4), isFalse);
    });

    test('duplicate ids still behave like a single selected id', () {
      final lookup = documentSelectionLookupOf(const [8, 8, 8]);

      expect(lookup.isSelectionActive, isTrue);
      expect(lookup.isSelected(8), isTrue);
      expect(lookup.isSelected(7), isFalse);
    });
  });
}
