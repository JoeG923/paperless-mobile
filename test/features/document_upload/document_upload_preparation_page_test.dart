import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_ce/hive.dart';
import 'package:dio/dio.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/database/tables/local_user_settings.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/features/document_upload/cubit/document_upload_cubit.dart';
import 'package:paperless_mobile/features/document_upload/view/document_upload_preparation_page.dart';
import 'package:paperless_mobile/features/tasks/model/pending_tasks_notifier.dart';
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

class FakeTasksApi implements PaperlessTasksApi {
  @override
  Future<Task?> find({int? id, String? taskId}) async => null;

  @override
  Future<Iterable<Task>> findAll([Iterable<int>? ids]) async => const [];

  @override
  Stream<Task> listenForTaskChanges(String taskId) => const Stream.empty();

  @override
  Future<Task> acknowledgeTask(Task task) async => task;

  @override
  Future<Iterable<Task>> acknowledgeTasks(Iterable<Task> tasks) async => tasks;
}

class FailingDocumentsApi implements PaperlessDocumentsApi {
  @override
  Future<String?> create(
    Uint8List documentBytes, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    throw const PaperlessApiException(ErrorCode.requestTimedOut);
  }

  @override
  Future<String?> createFromFile(
    String filePath, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    throw const PaperlessApiException(ErrorCode.requestTimedOut);
  }

  @override
  Future<DocumentModel> update(DocumentModel doc) {
    throw UnimplementedError();
  }

  @override
  Future<int> findNextAsn() {
    throw UnimplementedError();
  }

  @override
  Future<PagedSearchResult<DocumentModel>> findAll(DocumentFilter filter) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> find(int id, {bool fullPermissions = false}) {
    throw UnimplementedError();
  }

  @override
  Future<int> delete(DocumentModel doc) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentMetaData> getMetaData(int id) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> deleteNote(DocumentModel document, int noteId) {
    throw UnimplementedError();
  }

  @override
  Future<Iterable<int>> bulkAction(BulkAction action) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> getPreview(int docId) {
    throw UnimplementedError();
  }

  @override
  String getThumbnailUrl(int docId) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> downloadDocument(int id, {bool original = false}) {
    throw UnimplementedError();
  }

  @override
  Future<void> downloadToFile(
    int id,
    String localFilePath, {
    bool original = false,
    void Function(double progress)? onProgressChanged,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FieldSuggestions> findSuggestions(DocumentModel document) {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> autocomplete(String query, [int limit = 10]) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> addNote({
    required DocumentModel document,
    required String text,
  }) {
    throw UnimplementedError();
  }
}

class CancellableDocumentsApi implements PaperlessDocumentsApi {
  @override
  Future<String?> create(
    Uint8List documentBytes, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    if (cancelToken == null) {
      throw const PaperlessApiException(ErrorCode.requestCancelled);
    }
    await cancelToken.whenCancel;
    throw const PaperlessApiException(ErrorCode.requestCancelled);
  }

  @override
  Future<String?> createFromFile(
    String filePath, {
    required String filename,
    required String title,
    DateTime? createdAt,
    int? documentType,
    int? correspondent,
    int? storagePath,
    Iterable<int> tags = const [],
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    if (cancelToken == null) {
      throw const PaperlessApiException(ErrorCode.requestCancelled);
    }
    await cancelToken.whenCancel;
    throw const PaperlessApiException(ErrorCode.requestCancelled);
  }

  @override
  Future<DocumentModel> update(DocumentModel doc) {
    throw UnimplementedError();
  }

  @override
  Future<int> findNextAsn() {
    throw UnimplementedError();
  }

  @override
  Future<PagedSearchResult<DocumentModel>> findAll(DocumentFilter filter) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> find(int id, {bool fullPermissions = false}) {
    throw UnimplementedError();
  }

  @override
  Future<int> delete(DocumentModel doc) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentMetaData> getMetaData(int id) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> deleteNote(DocumentModel document, int noteId) {
    throw UnimplementedError();
  }

  @override
  Future<Iterable<int>> bulkAction(BulkAction action) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> getPreview(int docId) {
    throw UnimplementedError();
  }

  @override
  String getThumbnailUrl(int docId) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> downloadDocument(int id, {bool original = false}) {
    throw UnimplementedError();
  }

  @override
  Future<void> downloadToFile(
    int id,
    String localFilePath, {
    bool original = false,
    void Function(double progress)? onProgressChanged,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FieldSuggestions> findSuggestions(DocumentModel document) {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> autocomplete(String query, [int limit = 10]) {
    throw UnimplementedError();
  }

  @override
  Future<DocumentModel> addNote({
    required DocumentModel document,
    required String text,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    hiveDir = await Directory.systemTemp.createTemp('hive_upload_test_');
    Hive.init(hiveDir.path);
    registerHiveAdapters();
    final box = await Hive.openBox<GlobalSettings>(HiveBoxes.globalSettings);
    await box.setValue(
      GlobalSettings(preferredLocaleSubtag: 'en', loggedInUserId: '1'),
    );
  });

  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) {
      await hiveDir.delete(recursive: true);
    }
  });

  testWidgets('shows error snackbar when upload fails', (
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
          home: BlocProvider(
            create: (_) => DocumentUploadCubit(
              FailingDocumentsApi(),
              PendingTasksNotifier(FakeTasksApi()),
            ),
            child: DocumentUploadPreparationPage(
              fileBytes: Uint8List(4),
              fileExtension: '.pdf',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(find.text('The request to the server timed out.'), findsOneWidget);
  });

  testWidgets('shows snackbar when upload is cancelled', (
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
          home: BlocProvider(
            create: (_) => DocumentUploadCubit(
              CancellableDocumentsApi(),
              PendingTasksNotifier(FakeTasksApi()),
            ),
            child: DocumentUploadPreparationPage(
              fileBytes: Uint8List(4),
              fileExtension: '.pdf',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('The request was cancelled.'), findsOneWidget);
  });
}
