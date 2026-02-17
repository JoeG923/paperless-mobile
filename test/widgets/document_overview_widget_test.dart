import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/database/tables/local_user_settings.dart';
import 'package:paperless_mobile/core/repository/custom_field_repository.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/features/document_details/view/widgets/document_overview_widget.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class FakeLabelsApi implements PaperlessLabelsApi {
  @override
  Future<Correspondent?> getCorrespondent(int id) => Future.value(null);

  @override
  Future<List<Correspondent>> getCorrespondents([Iterable<int>? ids]) async =>
      [];

  @override
  Future<Correspondent> saveCorrespondent(Correspondent correspondent) async {
    throw UnimplementedError();
  }

  @override
  Future<Correspondent> updateCorrespondent(Correspondent correspondent) async {
    throw UnimplementedError();
  }

  @override
  Future<int> deleteCorrespondent(Correspondent correspondent) async {
    throw UnimplementedError();
  }

  @override
  Future<Tag?> getTag(int id) => Future.value(null);

  @override
  Future<List<Tag>> getTags([Iterable<int>? ids]) async => [];

  @override
  Future<Tag> saveTag(Tag tag) async {
    throw UnimplementedError();
  }

  @override
  Future<Tag> updateTag(Tag tag) async {
    throw UnimplementedError();
  }

  @override
  Future<int> deleteTag(Tag tag) async {
    throw UnimplementedError();
  }

  @override
  Future<DocumentType?> getDocumentType(int id) => Future.value(null);

  @override
  Future<List<DocumentType>> getDocumentTypes([Iterable<int>? ids]) async => [];

  @override
  Future<DocumentType> saveDocumentType(DocumentType type) async {
    throw UnimplementedError();
  }

  @override
  Future<DocumentType> updateDocumentType(DocumentType documentType) async {
    throw UnimplementedError();
  }

  @override
  Future<int> deleteDocumentType(DocumentType documentType) async {
    throw UnimplementedError();
  }

  @override
  Future<StoragePath?> getStoragePath(int id) => Future.value(null);

  @override
  Future<List<StoragePath>> getStoragePaths([Iterable<int>? ids]) async => [];

  @override
  Future<StoragePath> saveStoragePath(StoragePath path) async {
    throw UnimplementedError();
  }

  @override
  Future<StoragePath> updateStoragePath(StoragePath path) async {
    throw UnimplementedError();
  }

  @override
  Future<int> deleteStoragePath(StoragePath path) async {
    throw UnimplementedError();
  }
}

class FakeCustomFieldsApi implements CustomFieldsApi {
  @override
  Future<CustomFieldModel> createCustomField(
    CustomFieldModel customField,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<int> deleteCustomField(CustomFieldModel customField) async {
    throw UnimplementedError();
  }

  @override
  Future<CustomFieldModel?> getCustomField(int id) async => null;

  @override
  Future<List<CustomFieldModel>> getCustomFields() async => [];
}

void main() {
  testWidgets('DocumentOverviewWidget ignores missing label ids', (
    WidgetTester tester,
  ) async {
    final labels = LabelRepository(FakeLabelsApi());
    final user = UserModelV3(
      id: 1,
      username: 'tester',
      email: 'tester@example.com',
      firstName: 'Test',
      lastName: 'User',
      dateJoined: DateTime(2024, 1, 1),
      isStaff: false,
      isActive: true,
      isSuperuser: false,
      groups: const [],
      userPermissions: const [
        'view_tag',
        'view_document_type',
        'view_correspondent',
        'view_storage_path',
      ],
      inheritedPermissions: const [],
    );
    final account = LocalUserAccount(
      id: '1',
      serverUrl: 'https://example.com',
      settings: LocalUserSettings(),
      paperlessUser: user,
      apiVersion: 3,
    );
    final document = DocumentModel(
      id: 1,
      title: 'Test Document',
      content: 'Content',
      tags: const [1],
      documentType: 1,
      correspondent: 1,
      storagePath: 1,
      created: DateTime(2024, 1, 1),
      modified: DateTime(2024, 1, 2),
      added: DateTime(2024, 1, 3),
      archiveSerialNumber: null,
      originalFileName: null,
      archivedFileName: null,
      owner: null,
      userCanChange: null,
      permissions: null,
      customFields: const [],
      notes: const [],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<LocalUserAccount>.value(value: account),
          ChangeNotifierProvider<LabelRepository>.value(value: labels),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: DocumentOverviewWidget(
              document: document,
              itemSpacing: 16,
              queryString: null,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('DocumentOverviewWidget renders custom field values', (
    WidgetTester tester,
  ) async {
    final labels = LabelRepository(FakeLabelsApi());
    final customFields = CustomFieldRepository(FakeCustomFieldsApi())
      ..customFields = {
        7: CustomFieldModel(
          id: 7,
          name: 'Invoice Number',
          dataType: CustomFieldDataType.string,
        ),
      };
    final user = UserModelV3(
      id: 1,
      username: 'tester',
      email: 'tester@example.com',
      firstName: 'Test',
      lastName: 'User',
      dateJoined: DateTime(2024, 1, 1),
      isStaff: false,
      isActive: true,
      isSuperuser: false,
      groups: const [],
      userPermissions: const ['view_customfield', 'view_document'],
      inheritedPermissions: const [],
    );
    final account = LocalUserAccount(
      id: '1',
      serverUrl: 'https://example.com',
      settings: LocalUserSettings(),
      paperlessUser: user,
      apiVersion: 8,
    );
    final document = DocumentModel(
      id: 1,
      title: 'Test Document',
      content: 'Content',
      tags: const [],
      documentType: null,
      correspondent: null,
      storagePath: null,
      created: DateTime(2024, 1, 1),
      modified: DateTime(2024, 1, 2),
      added: DateTime(2024, 1, 3),
      archiveSerialNumber: null,
      originalFileName: null,
      archivedFileName: null,
      owner: null,
      userCanChange: null,
      permissions: null,
      customFields: const [CustomFieldInstance(id: 7, value: 'INV-2026-0001')],
      notes: const [],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<LocalUserAccount>.value(value: account),
          ChangeNotifierProvider<LabelRepository>.value(value: labels),
          ChangeNotifierProvider<CustomFieldRepository>.value(
            value: customFields,
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
          home: Scaffold(
            body: DocumentOverviewWidget(
              document: document,
              itemSpacing: 16,
              queryString: null,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Invoice Number'), findsOneWidget);
    expect(find.text('INV-2026-0001'), findsOneWidget);
  });
}
