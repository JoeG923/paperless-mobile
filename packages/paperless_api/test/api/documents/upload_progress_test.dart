import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/src/modules/documents_api/paperless_documents_api.dart';
import 'package:paperless_api/src/modules/documents_api/paperless_documents_api_impl.dart';

Future<FormData> _captureUploadFormData(
  Future<String?> Function(PaperlessDocumentsApiImpl api) upload,
) async {
  final dio = Dio();
  final api = PaperlessDocumentsApiImpl(dio);
  FormData? captured;
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final payload = options.data;
        if (payload is FormData) {
          captured = payload;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: 'task-id-1',
            ),
          );
          return;
        }
        handler.reject(
          DioException(
            requestOptions: options,
            error: 'Expected FormData payload',
          ),
        );
      },
    ),
  );
  final taskId = await upload(api);
  expect(taskId, 'task-id-1');
  return captured!;
}

void main() {
  test('safeProgress returns 0.0 when total is zero', () {
    expect(safeProgress(10, 0), 0.0);
  });

  test('safeProgress returns fraction when total is positive', () {
    expect(safeProgress(5, 10), 0.5);
  });

  test('createFromFile uploads document and returns task id', () async {
    final tempDir = await Directory.systemTemp.createTemp('paperless_api_');
    final file = File('${tempDir.path}/upload.txt');
    await file.writeAsString('content');

    final formData = await _captureUploadFormData(
      (api) => api.createFromFile(
        file.path,
        filename: 'upload.txt',
        title: 'upload',
      ),
    );

    expect(formData.fields.any((entry) => entry.key == 'title'), isTrue);

    await tempDir.delete(recursive: true);
  });

  test('create serializes custom_fields when provided as id list', () async {
    final formData = await _captureUploadFormData(
      (api) => api.create(
        Uint8List.fromList([1, 2, 3]),
        filename: 'upload.pdf',
        title: 'upload',
        customFields: UploadCustomFields.ids([1, 2, 3]),
      ),
    );

    final serialized = formData.fields.firstWhere(
      (entry) => entry.key == 'custom_fields',
    );
    expect(jsonDecode(serialized.value), [1, 2, 3]);
  });

  test(
    'create serializes custom_fields when provided as id value map',
    () async {
      final formData = await _captureUploadFormData(
        (api) => api.create(
          Uint8List.fromList([1, 2, 3]),
          filename: 'upload.pdf',
          title: 'upload',
          customFields: UploadCustomFields.values({7: 'hello', 9: 123}),
        ),
      );

      final serialized = formData.fields.firstWhere(
        (entry) => entry.key == 'custom_fields',
      );
      expect(jsonDecode(serialized.value), {'7': 'hello', '9': 123});
    },
  );
}
