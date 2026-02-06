import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:paperless_api/src/modules/documents_api/paperless_documents_api_impl.dart';

void main() {
  test('safeProgress returns 0.0 when total is zero', () {
    expect(safeProgress(10, 0), 0.0);
  });

  test('safeProgress returns fraction when total is positive', () {
    expect(safeProgress(5, 10), 0.5);
  });

  test('createFromFile uploads document and returns task id', () async {
    final dio = Dio();
    final mockAdapter = DioAdapter(dio: dio);
    final api = PaperlessDocumentsApiImpl(dio);
    final tempDir = await Directory.systemTemp.createTemp('paperless_api_');
    final file = File('${tempDir.path}/upload.txt');
    await file.writeAsString('content');

    mockAdapter.onPost(
      '/api/documents/post_document/',
      data: Matchers.any,
      (server) => server.reply(200, 'task-id-1'),
    );

    final taskId = await api.createFromFile(
      file.path,
      filename: 'upload.txt',
      title: 'upload',
    );

    expect(taskId, 'task-id-1');
    await tempDir.delete(recursive: true);
  });
}
