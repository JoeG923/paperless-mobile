import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/constants.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/hive/hive_extensions.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';
import 'package:paperless_mobile/core/database/tables/local_user_account.dart';
import 'package:paperless_mobile/core/database/tables/local_user_settings.dart';
import 'package:paperless_mobile/core/interceptor/api_version_interceptor.dart';
import 'package:paperless_mobile/features/ai/model/ai_feature_status.dart';
import 'package:pdf/widgets.dart' as pw;

const _baseUrl = String.fromEnvironment('E2E_PAPERLESS_BASE_URL');
const _username = String.fromEnvironment(
  'E2E_PAPERLESS_USERNAME',
  defaultValue: 'e2e',
);
const _password = String.fromEnvironment(
  'E2E_PAPERLESS_PASSWORD',
  defaultValue: 'e2e-pass-123',
);
const _expectedApiVersion = String.fromEnvironment('E2E_EXPECTED_API_VERSION');

void main() {
  late Directory hiveDir;

  setUpAll(() {
    if (_baseUrl.isEmpty) {
      return;
    }
    hiveDir = Directory.systemTemp.createTempSync('paperless-api-e2e-hive-');
    Hive.init(hiveDir.path);
    if (!Hive.isAdapterRegistered(HiveTypeIds.globalSettings)) {
      registerHiveAdapters();
    }
  });

  setUp(() async {
    if (_baseUrl.isEmpty) {
      return;
    }
    await Hive.openBox<GlobalSettings>(HiveBoxes.globalSettings);
    await Hive.openBox<LocalUserAccount>(HiveBoxes.localUserAccount);
    await Hive.globalSettingsBox.clear();
    await Hive.localUserAccountBox.clear();
  });

  tearDown(() async {
    if (_baseUrl.isEmpty) {
      return;
    }
    await Hive.close();
  });

  tearDownAll(() async {
    if (_baseUrl.isEmpty) {
      return;
    }
    await hiveDir.delete(recursive: true);
  });

  test(
    'negotiates the selected API version and round-trips an upload',
    () async {
      final dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(seconds: 30),
        ),
      )..interceptors.add(DioHttpErrorInterceptor());

      final token = await PaperlessAuthenticationApiImpl(
        dio,
      ).login(username: _username, password: _password);
      dio.options.headers['Authorization'] = 'Token $token';

      final profileResponse = await dio.get('/api/profile/');
      final serverApiVersion = int.parse(
        profileResponse.headers.value('x-api-version') ?? '0',
      );
      if (_expectedApiVersion.isNotEmpty) {
        final expectedApiVersion = int.parse(_expectedApiVersion);
        expect(serverApiVersion, expectedApiVersion);
        expect(
          selectedApiVersionForServer(serverApiVersion),
          selectedApiVersionForServer(expectedApiVersion),
        );
      }
      final selectedApiVersion = selectedApiVersionForServer(serverApiVersion);

      final accountId = '$_username@$_baseUrl';
      await Hive.globalSettingsBox.setValue(
        GlobalSettings(preferredLocaleSubtag: 'en', loggedInUserId: accountId),
      );
      await Hive.localUserAccountBox.put(
        accountId,
        LocalUserAccount(
          id: accountId,
          serverUrl: _baseUrl,
          settings: LocalUserSettings(),
          paperlessUser: const UserModelV3(
            id: 1,
            username: _username,
            isStaff: true,
            isActive: true,
            isSuperuser: true,
            groups: [],
            userPermissions: [],
            inheritedPermissions: [],
          ),
          apiVersion: selectedApiVersion,
          serverApiVersion: serverApiVersion,
        ),
      );

      final recordedAcceptHeaders = <String?>[];
      dio.interceptors.insert(0, ApiVersionInterceptor());
      dio.interceptors.insert(1, _RequestHeaderRecorder(recordedAcceptHeaders));
      await dio.get('/api/profile/');
      expect(
        recordedAcceptHeaders.last,
        'application/json; version=$selectedApiVersion',
      );

      if (serverApiVersion >= 10) {
        final account = Hive.localUserAccountBox.get(accountId)!;
        account.apiVersion = 9;
        await account.save();
        await dio.get('/api/profile/');
        final updatedAccount = Hive.localUserAccountBox.get(accountId)!;
        expect(recordedAcceptHeaders.last, 'application/json; version=10');
        expect(updatedAccount.apiVersion, 10);
      }

      final uploadedDocument = await _roundTripUpload(
        dio: dio,
        apiVersion: selectedApiVersion,
      );
      await _verifyAiCapabilities(
        dio: dio,
        selectedApiVersion: selectedApiVersion,
        uploadedDocument: uploadedDocument,
      );
    },
    skip: _baseUrl.isEmpty
        ? 'Set E2E_PAPERLESS_BASE_URL to run against a real paperless server.'
        : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _RequestHeaderRecorder extends Interceptor {
  final List<String?> acceptHeaders;

  _RequestHeaderRecorder(this.acceptHeaders);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    acceptHeaders.add(options.headers[Headers.acceptHeader]?.toString());
    handler.next(options);
  }
}

Future<DocumentModel> _roundTripUpload({
  required Dio dio,
  required int apiVersion,
}) async {
  final documentsApi = PaperlessDocumentsApiImpl(dio, apiVersion: apiVersion);
  final labelsApi = PaperlessLabelApiImpl(dio);
  final tasksApi = PaperlessTasksApiImpl(dio, apiVersion: apiVersion);

  await labelsApi.getTags();

  final uniqueId = DateTime.now().microsecondsSinceEpoch;
  final title = 'codex-api-e2e-$uniqueId';
  final document = pw.Document()
    ..addPage(
      pw.Page(build: (_) => pw.Text('Paperless Mobile API E2E run $uniqueId')),
    );
  final sourceBytes = Uint8List.fromList(await document.save());
  final tempDir = await Directory.systemTemp.createTemp('paperless_api_e2e_');
  final sourceFile = File('${tempDir.path}/$title.pdf');

  try {
    await sourceFile.writeAsBytes(sourceBytes, flush: true);
    final taskId = await documentsApi.createFromFile(
      sourceFile.path,
      filename: '$title.pdf',
      title: title,
      timeout: const Duration(minutes: 2),
    );

    if (taskId != null && taskId.isNotEmpty) {
      final task = await _waitForTask(
        tasksApi,
        taskId,
        timeout: const Duration(minutes: 3),
      );
      expect(task.status, TaskStatus.success, reason: task.result);
    }

    final uploadedDocument = await _waitForDocumentByTitle(
      documentsApi,
      title,
      timeout: const Duration(minutes: 3),
    );
    final titleAndContentPage = await documentsApi.findAll(
      DocumentFilter(
        page: 1,
        pageSize: 10,
        query: TextQuery.titleAndContent(title),
      ),
    );
    expect(
      titleAndContentPage.results.map((document) => document.id),
      contains(uploadedDocument.id),
    );
    final downloadedBytes = await documentsApi.downloadDocument(
      uploadedDocument.id,
      original: true,
    );

    expect(downloadedBytes, sourceBytes);
    return uploadedDocument;
  } finally {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  }
}

Future<void> _verifyAiCapabilities({
  required Dio dio,
  required int selectedApiVersion,
  required DocumentModel uploadedDocument,
}) async {
  final serverStatsApi = PaperlessServerStatsApiImpl(dio);
  final status = await AiFeatureStatus.load(
    serverStatsApi: serverStatsApi,
    apiVersion: selectedApiVersion,
  );

  if (selectedApiVersion < 10) {
    expect(status.enabled, isFalse);
    return;
  }

  final uiSettings = await serverStatsApi.getUiSettings();
  expect(status.enabled, uiSettings.aiEnabled);
  if (!uiSettings.aiEnabled) {
    return;
  }

  final systemStatus = await serverStatsApi.getSystemStatus();
  expect(systemStatus.llmIndexStatus, isNotNull);

  final documentsApi = PaperlessDocumentsApiImpl(dio, apiVersion: 10);
  final suggestions = await documentsApi.findAiSuggestions(uploadedDocument.id);
  expect(suggestions, isA<AiDocumentSuggestions>());
}

Future<Task> _waitForTask(
  PaperlessTasksApi tasksApi,
  String taskId, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  Task? latestTask;

  while (DateTime.now().isBefore(deadline)) {
    latestTask = await tasksApi.find(taskId: taskId);
    if (latestTask == null) {
      await Future<void>.delayed(const Duration(seconds: 2));
      continue;
    }

    if (latestTask.status == TaskStatus.success ||
        latestTask.status == TaskStatus.failure) {
      return latestTask;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  throw TestFailure(
    'Timed out waiting for task $taskId. Last task state: ${latestTask?.status}',
  );
}

Future<DocumentModel> _waitForDocumentByTitle(
  PaperlessDocumentsApi documentsApi,
  String title, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    final page = await documentsApi.findAll(
      DocumentFilter(
        page: 1,
        pageSize: 10,
        sortField: SortField.added,
        sortOrder: SortOrder.descending,
        query: TextQuery.title(title),
      ),
    );
    for (final document in page.results) {
      if (document.title == title) {
        return document;
      }
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  throw TestFailure(
    'Timed out waiting for uploaded document with title $title',
  );
}
