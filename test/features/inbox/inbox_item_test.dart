import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/database/tables/local_user_settings.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/core/service/connectivity_status_service.dart';
import 'package:paperless_mobile/features/inbox/view/widgets/inbox_item.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _FakeLabelsApi extends Fake implements PaperlessLabelsApi {
  @override
  Future<List<Tag>> getTags([Iterable<int>? ids]) async => const [];
}

class _FakeDocumentsApi extends Fake implements PaperlessDocumentsApi {
  @override
  String getThumbnailUrl(int docId) => 'https://example.invalid/$docId.png';
}

UserModelV3 _userWithDocumentEditPermissions() {
  return const UserModelV3(
    id: 1,
    username: 'tester',
    isStaff: false,
    isActive: true,
    isSuperuser: false,
    groups: [],
    userPermissions: ['change_document', 'delete_document'],
    inheritedPermissions: [],
  );
}

DocumentModel _document() {
  final now = DateTime(2026, 1, 1);
  return DocumentModel(
    id: 1,
    title: 'Inbox item',
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
  testWidgets('InboxItem renders v3 document actions without dynamic lookup', (
    tester,
  ) async {
    final account = LocalUserAccount(
      id: '1',
      serverUrl: 'https://example.invalid',
      settings: LocalUserSettings(),
      paperlessUser: _userWithDocumentEditPermissions(),
      apiVersion: 10,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<LocalUserAccount>.value(value: account),
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
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: Scaffold(body: InboxItem(document: _document())),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Assign ASN'), findsOneWidget);
    expect(find.text('Delete document'), findsOneWidget);
  });
}
