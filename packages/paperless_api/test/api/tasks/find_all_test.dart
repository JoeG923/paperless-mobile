import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  test('findAll forwards id filter as id__in query parameter', () async {
    final dio = Dio();
    Map<String, dynamic>? capturedQueryParameters;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/tasks/') {
            capturedQueryParameters = options.queryParameters;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: [_taskJson(3, 'task-3', 'PENDING')],
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

    final api = PaperlessTasksApiImpl(dio);
    final result = await api.findAll([3, 7, 9]);

    expect(result.map((task) => task.id), [3]);
    expect(capturedQueryParameters, {'id__in': '3,7,9'});
  });

  test('findAll batches large id lists across multiple requests', () async {
    final dio = Dio();
    final capturedIdQueries = <String>[];

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/tasks/') {
            final idIn = options.queryParameters['id__in'] as String?;
            if (idIn != null) {
              capturedIdQueries.add(idIn);
              final ids = idIn
                  .split(',')
                  .map((value) => int.parse(value))
                  .toList(growable: false);
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    for (final id in ids) _taskJson(id, 'task-$id', 'PENDING'),
                  ],
                ),
              );
              return;
            }
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

    final api = PaperlessTasksApiImpl(dio);
    final ids = List<int>.generate(205, (index) => index + 1);
    final result = await api.findAll(ids);

    expect(capturedIdQueries.length, 3);
    expect(capturedIdQueries[0].split(',').length, 100);
    expect(capturedIdQueries[1].split(',').length, 100);
    expect(capturedIdQueries[2].split(',').length, 5);
    expect(result.length, 205);
    expect(result.first.id, 1);
    expect(result.last.id, 205);
  });
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
