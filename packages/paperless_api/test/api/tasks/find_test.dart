import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  test(
    'find by task id sends task_id query parameter on tasks endpoint',
    () async {
      final dio = Dio();
      String? capturedPath;
      Map<String, dynamic>? capturedQueryParameters;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedPath = options.path;
            capturedQueryParameters = options.queryParameters;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: [_taskJson(11, 'task/with?chars', 'PENDING')],
              ),
            );
          },
        ),
      );

      final api = PaperlessTasksApiImpl(dio);
      final task = await api.find(taskId: 'task/with?chars');

      expect(capturedPath, '/api/tasks/');
      expect(capturedQueryParameters, {'task_id': 'task/with?chars'});
      expect(task?.id, 11);
      expect(task?.taskId, 'task/with?chars');
    },
  );
}

Map<String, dynamic> _taskJson(int id, String taskId, String status) {
  return {
    'id': id,
    'task_id': taskId,
    'task_file_name': 'upload.pdf',
    'date_created': '2026-02-16T00:00:00Z',
    'status': status,
    'acknowledged': false,
  };
}
