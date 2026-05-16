import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_ce/hive.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/database/tables/local_user_settings.dart';
import 'package:paperless_mobile/core/repository/custom_field_repository.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/core/service/document_upload_service.dart';
import 'package:paperless_mobile/features/document_upload/cubit/document_upload_cubit.dart';
import 'package:paperless_mobile/features/document_upload/view/document_upload_preparation_page.dart';
import 'package:paperless_mobile/features/tasks/model/pending_tasks_notifier.dart';
import 'package:paperless_mobile/generated/l10n/app_localizations.dart';
import 'package:paperless_mobile/features/logging/data/logger.dart'
    as app_logger;
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

class FakeCustomFieldsApi implements CustomFieldsApi {
  @override
  Future<CustomFieldModel> createCustomField(CustomFieldModel customField) {
    throw UnimplementedError();
  }

  @override
  Future<int> deleteCustomField(CustomFieldModel customField) {
    throw UnimplementedError();
  }

  @override
  Future<CustomFieldModel?> getCustomField(int id) async => null;

  @override
  Future<List<CustomFieldModel>> getCustomFields() async => const [];
}

class FailingDocumentsApi implements PaperlessDocumentsApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

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
    UploadCustomFields? customFields,
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
    UploadCustomFields? customFields,
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

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
    UploadCustomFields? customFields,
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
    UploadCustomFields? customFields,
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

class RecordingFailingDocumentsApi extends FailingDocumentsApi {
  UploadCustomFields? lastCustomFields;
  String? lastFilename;
  String? lastTitle;
  int? lastDocumentType;
  int? lastCorrespondent;
  int? lastStoragePath;
  List<int>? lastTags;
  DateTime? lastCreatedAt;
  int? lastAsn;

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
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    lastCustomFields = customFields;
    lastFilename = filename;
    lastTitle = title;
    lastDocumentType = documentType;
    lastCorrespondent = correspondent;
    lastStoragePath = storagePath;
    lastTags = tags.toList();
    lastCreatedAt = createdAt;
    lastAsn = asn;
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
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    lastCustomFields = customFields;
    lastFilename = filename;
    lastTitle = title;
    lastDocumentType = documentType;
    lastCorrespondent = correspondent;
    lastStoragePath = storagePath;
    lastTags = tags.toList();
    lastCreatedAt = createdAt;
    lastAsn = asn;
    throw const PaperlessApiException(ErrorCode.requestTimedOut);
  }
}

class RecordingSuccessDocumentsApi extends RecordingFailingDocumentsApi {
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
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    lastCustomFields = customFields;
    lastFilename = filename;
    lastTitle = title;
    lastDocumentType = documentType;
    lastCorrespondent = correspondent;
    lastStoragePath = storagePath;
    lastTags = tags.toList();
    lastCreatedAt = createdAt;
    lastAsn = asn;
    return 'task-1';
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
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    lastCustomFields = customFields;
    lastFilename = filename;
    lastTitle = title;
    lastDocumentType = documentType;
    lastCorrespondent = correspondent;
    lastStoragePath = storagePath;
    lastTags = tags.toList();
    lastCreatedAt = createdAt;
    lastAsn = asn;
    return null;
  }
}

class RecordingSuccessNoTaskDocumentsApi extends RecordingSuccessDocumentsApi {
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
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    lastCustomFields = customFields;
    lastFilename = filename;
    lastTitle = title;
    lastDocumentType = documentType;
    lastCorrespondent = correspondent;
    lastStoragePath = storagePath;
    lastTags = tags.toList();
    lastCreatedAt = createdAt;
    lastAsn = asn;
    return null;
  }
}

class CountingFailingDocumentsApi extends FailingDocumentsApi {
  int createCallCount = 0;
  int createFromFileCallCount = 0;

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
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    createCallCount += 1;
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
    UploadCustomFields? customFields,
    int? asn,
    void Function(double progress)? onProgressChanged,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    createFromFileCallCount += 1;
    throw const PaperlessApiException(ErrorCode.requestTimedOut);
  }
}

DocumentUploadCubit _buildFastRetryCubit(PaperlessDocumentsApi api) {
  final tasksNotifier = PendingTasksNotifier(FakeTasksApi());
  return DocumentUploadCubit(
    api,
    tasksNotifier,
    uploadService: DocumentUploadService(
      api,
      tasksNotifier,
      maxRetryAttempts: 0,
      sleep: (_) async {},
    ),
  );
}

void main() {
  setUp(() {
    app_logger.logger = Logger(level: Level.off);
  });

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
            create: (_) => _buildFastRetryCubit(FailingDocumentsApi()),
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
            create: (_) => _buildFastRetryCubit(CancellableDocumentsApi()),
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

  testWidgets('collects upload custom fields and forwards them to API', (
    WidgetTester tester,
  ) async {
    final labels = LabelRepository(FakeLabelsApi());
    final customFields = CustomFieldRepository(FakeCustomFieldsApi())
      ..customFields = {
        11: CustomFieldModel(
          id: 11,
          name: 'Invoice number',
          dataType: CustomFieldDataType.integer,
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
      userPermissions: const [
        'view_tag',
        'view_document_type',
        'view_correspondent',
        'view_storage_path',
        'view_customfield',
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
    final api = RecordingFailingDocumentsApi();

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
          home: BlocProvider(
            create: (_) => _buildFastRetryCubit(api),
            child: DocumentUploadPreparationPage(
              fileBytes: Uint8List(4),
              fileExtension: '.pdf',
            ),
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('customField_11')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('customField_11')),
      '123',
    );
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    final captured = api.lastCustomFields;
    expect(captured, isA<UploadCustomFieldValues>());
    expect((captured as UploadCustomFieldValues).values[11], 123);
  });

  testWidgets('blocks upload when required title is empty', (
    WidgetTester tester,
  ) async {
    final labels = LabelRepository(FakeLabelsApi());
    final api = CountingFailingDocumentsApi();
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
            create: (_) => _buildFastRetryCubit(api),
            child: DocumentUploadPreparationPage(
              fileBytes: Uint8List(4),
              fileExtension: '.pdf',
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>(DocumentModel.titleKey)),
      '',
    );
    await tester.tap(find.text('Upload'));
    await tester.pump();

    expect(api.createCallCount, 0);
    expect(api.createFromFileCallCount, 0);
    expect(find.text('This field is required!'), findsOneWidget);
  });

  testWidgets(
    'does not duplicate file extension when filename already has extension',
    (WidgetTester tester) async {
      final labels = LabelRepository(FakeLabelsApi());
      final api = RecordingSuccessNoTaskDocumentsApi();
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
              create: (_) => _buildFastRetryCubit(api),
              child: DocumentUploadPreparationPage(
                fileBytes: Uint8List(4),
                filename: 'existing.pdf',
                fileExtension: '.pdf',
              ),
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('filename')),
        'existing.pdf',
      );
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();

      expect(api.lastFilename, 'existing.pdf');
    },
  );

  testWidgets('synchronizes title and filename and pads file extension', (
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
    final api = RecordingSuccessNoTaskDocumentsApi();
    final tasksNotifier = PendingTasksNotifier(FakeTasksApi());
    final cubit = DocumentUploadCubit(
      api,
      tasksNotifier,
      uploadService: DocumentUploadService(
        api,
        tasksNotifier,
        maxRetryAttempts: 0,
        sleep: (_) async {},
      ),
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
            create: (_) => cubit,
            child: DocumentUploadPreparationPage(
              fileBytes: Uint8List(4),
              fileExtension: '.pdf',
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>(DocumentModel.titleKey)),
      'Invoice 2024',
    );
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(api.lastTitle, 'Invoice 2024');
    expect(api.lastFilename, 'invoice 2024.pdf');
    await cubit.close();
    tasksNotifier.dispose();
  });
}
