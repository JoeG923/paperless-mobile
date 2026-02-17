import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  test(
    'listenForTaskChanges uses adaptive backoff and resets on status change',
    () async {
      final dio = Dio();
      final durations = <Duration>[];
      final responses = Queue<Map<String, dynamic>>.from([
        _taskJson(1, 'task-1', 'PENDING'),
        _taskJson(1, 'task-1', 'PENDING'),
        _taskJson(1, 'task-1', 'PENDING'),
        _taskJson(1, 'task-1', 'STARTED'),
        _taskJson(1, 'task-1', 'STARTED'),
        _taskJson(1, 'task-1', 'SUCCESS'),
      ]);

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/tasks/' &&
                options.queryParameters['task_id'] == 'task-1') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [responses.removeFirst()],
                ),
              );
              return;
            }

            handler.reject(
              DioException(
                requestOptions: options,
                error: 'Unexpected request: ${options.path}',
              ),
            );
          },
        ),
      );

      final api = PaperlessTasksApiImpl(
        dio,
        minPollInterval: const Duration(seconds: 1),
        maxPollInterval: const Duration(seconds: 4),
        sleep: (duration) async {
          durations.add(duration);
        },
      );

      final statusSequence = await api
          .listenForTaskChanges('task-1')
          .map((task) => task.status)
          .toList();

      expect(statusSequence, [
        TaskStatus.pending,
        TaskStatus.pending,
        TaskStatus.pending,
        TaskStatus.started,
        TaskStatus.started,
        TaskStatus.success,
      ]);
      expect(durations, [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
        const Duration(seconds: 4),
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
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
