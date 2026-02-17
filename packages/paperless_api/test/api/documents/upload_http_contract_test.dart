import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';

class _CapturedUploadRequest {
  const _CapturedUploadRequest({
    required this.method,
    required this.path,
    required this.contentType,
    required this.body,
  });

  final String method;
  final String path;
  final String? contentType;
  final String body;
}

Future<(_CapturedUploadRequest request, String? taskId)> _captureUploadRequest(
  Future<String?> Function(PaperlessDocumentsApiImpl api) upload,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final requestFuture = server.first;
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://${server.address.address}:${server.port}',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
    ),
  );
  final api = PaperlessDocumentsApiImpl(dio);

  final uploadFuture = upload(api);
  final request = await requestFuture;
  final bodyBytes = <int>[];
  await for (final chunk in request) {
    bodyBytes.addAll(chunk);
  }
  request.response.statusCode = 200;
  request.response.write('task-http-1');
  await request.response.close();

  final taskId = await uploadFuture;
  await server.close(force: true);

  return (
    _CapturedUploadRequest(
      method: request.method,
      path: request.uri.path,
      contentType: request.headers.contentType?.mimeType,
      body: utf8.decode(bodyBytes, allowMalformed: true),
    ),
    taskId,
  );
}

void main() {
  test(
    'create sends multipart upload contract fields to HTTP server',
    () async {
      final (request, taskId) = await _captureUploadRequest(
        (api) => api.create(
          Uint8List.fromList([1, 2, 3, 4]),
          filename: 'scan.pdf',
          title: 'invoice-2026',
          tags: const [7, 9],
          customFields: UploadCustomFields.values({3: 'PO-42'}),
        ),
      );

      expect(taskId, 'task-http-1');
      expect(request.method, 'POST');
      expect(request.path, '/api/documents/post_document/');
      expect(request.contentType, 'multipart/form-data');
      expect(request.body, contains('name="document"; filename="scan.pdf"'));
      expect(request.body, contains('name="title"'));
      expect(request.body, contains('invoice-2026'));
      expect(request.body, contains('name="custom_fields"'));
      expect(request.body, contains('{"3":"PO-42"}'));
      expect(request.body, contains('name="tags"'));
      expect(request.body, contains('\r\n7\r\n'));
      expect(request.body, contains('\r\n9\r\n'));
    },
  );

  test('createFromFile sends multipart file payload to HTTP server', () async {
    final tempDir = await Directory.systemTemp.createTemp('upload_http_');
    final file = File('${tempDir.path}/from_file.txt');
    await file.writeAsString('abc');

    final (request, taskId) = await _captureUploadRequest(
      (api) => api.createFromFile(
        file.path,
        filename: 'from_file.txt',
        title: 'from-file',
      ),
    );

    expect(taskId, 'task-http-1');
    expect(request.method, 'POST');
    expect(request.path, '/api/documents/post_document/');
    expect(request.contentType, 'multipart/form-data');
    expect(request.body, contains('name="document"; filename="from_file.txt"'));
    expect(request.body, contains('name="title"'));
    expect(request.body, contains('from-file'));

    await tempDir.delete(recursive: true);
  });
}
