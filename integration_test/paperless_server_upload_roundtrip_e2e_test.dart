import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:pdf/widgets.dart' as pw;

const _defaultBaseUrl = String.fromEnvironment(
  'E2E_PAPERLESS_BASE_URL',
  defaultValue: 'http://10.0.2.2:18000',
);
const _defaultUsername = String.fromEnvironment(
  'E2E_PAPERLESS_USERNAME',
  defaultValue: 'e2e',
);
const _defaultPassword = String.fromEnvironment(
  'E2E_PAPERLESS_PASSWORD',
  defaultValue: 'e2e-pass-123',
);
const _expectedApiVersion = String.fromEnvironment(
  'E2E_EXPECTED_API_VERSION',
  defaultValue: '',
);

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'upload roundtrip keeps original bytes intact on paperless server',
    (_) async {
      final dio = Dio(
        BaseOptions(
          baseUrl: _defaultBaseUrl,
          connectTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(seconds: 30),
        ),
      )..interceptors.add(DioHttpErrorInterceptor());

      final authApi = PaperlessAuthenticationApiImpl(dio);
      final token = await authApi.login(
        username: _defaultUsername,
        password: _defaultPassword,
      );
      dio.options.headers['Authorization'] = 'Token $token';

      final apiRootResponse = await dio.get('/api/profile/');
      expect(apiRootResponse.statusCode, 200);
      final serverApiVersion = int.parse(
        apiRootResponse.headers.value('x-api-version') ?? '0',
      );
      if (_expectedApiVersion.isNotEmpty) {
        expect(serverApiVersion, int.parse(_expectedApiVersion));
      }

      final documentsApi = PaperlessDocumentsApiImpl(
        dio,
        apiVersion: serverApiVersion,
      );
      final labelsApi = PaperlessLabelApiImpl(dio);
      final tasksApi = PaperlessTasksApiImpl(dio, apiVersion: serverApiVersion);

      await labelsApi.getTags();

      final uniqueId = DateTime.now().microsecondsSinceEpoch;
      final title = 'codex-upload-roundtrip-$uniqueId';
      final document = pw.Document()
        ..addPage(
          pw.Page(build: (_) => pw.Text('Paperless Mobile E2E run $uniqueId')),
        );
      final sourceBytes = Uint8List.fromList(await document.save());
      final tempDir = await Directory.systemTemp.createTemp(
        'paperless_upload_roundtrip_',
      );
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
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    },
  );
}
