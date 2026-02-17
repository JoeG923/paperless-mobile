import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paperless_api/paperless_api.dart';

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

      final documentsApi = PaperlessDocumentsApiImpl(dio);
      final tasksApi = PaperlessTasksApiImpl(dio, apiVersion: 6);

      final uniqueId = DateTime.now().microsecondsSinceEpoch;
      final title = 'codex-upload-roundtrip-$uniqueId';
      final sourceBytes = Uint8List.fromList(
        '%PDF-1.4\n'
                '% run-id: $uniqueId\n'
                '1 0 obj\n'
                '<< /Type /Catalog /Pages 2 0 R >>\n'
                'endobj\n'
                '2 0 obj\n'
                '<< /Type /Pages /Count 1 /Kids [3 0 R] >>\n'
                'endobj\n'
                '3 0 obj\n'
                '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >>\n'
                'endobj\n'
                'trailer\n'
                '<< /Root 1 0 R >>\n'
                '%%EOF\n'
            .codeUnits,
      );
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

        final document = await _waitForDocumentByTitle(
          documentsApi,
          title,
          timeout: const Duration(minutes: 3),
        );
        final downloadedBytes = await documentsApi.downloadDocument(
          document.id,
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
