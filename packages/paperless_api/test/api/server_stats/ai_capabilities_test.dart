import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  test('ui settings expose AI enabled flag from v3 settings payload', () {
    final settings = PaperlessUiSettingsModel.fromJson({
      'display_name': 'paperless',
      'settings': {'ai_enabled': true},
    });

    expect(settings.aiEnabled, isTrue);
  });

  test('server stats API reads system status LLM index fields', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/api/status/');
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'tasks': {
                  'llmindex_status': 'ERROR',
                  'llmindex_last_modified': '2026-05-15T00:00:00Z',
                  'llmindex_error': 'Index failed',
                },
              },
            ),
          );
        },
      ),
    );
    final api = PaperlessServerStatsApiImpl(dio);

    final status = await api.getSystemStatus();

    expect(status.llmIndexStatus, SystemStatusItemStatus.error);
    expect(status.llmIndexError, 'Index failed');
  });
}
