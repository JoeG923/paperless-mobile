import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:paperless_api/paperless_api.dart';

void main() {
  group('DioHttpErrorInterceptor', () {
    late Dio dio;
    late DioAdapter mockAdapter;

    setUp(() {
      dio = Dio()..interceptors.add(DioHttpErrorInterceptor());
      mockAdapter = DioAdapter(dio: dio);
    });

    test('forwards non-400 errors', () async {
      mockAdapter.onGet(
        '/failing-endpoint',
        (server) => server.reply(500, {'detail': 'server error'}),
      );

      await expectLater(
        dio.get('/failing-endpoint').timeout(const Duration(seconds: 1)),
        throwsA(
          isA<DioException>().having(
            (error) => error.response?.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
    });

    test('maps string 400 payload to a PaperlessApiException', () async {
      mockAdapter.onGet(
        '/bad-request',
        (server) => server.reply(400, 'some text error'),
      );

      await expectLater(
        dio.get('/bad-request'),
        throwsA(
          isA<DioException>().having(
            (error) => error.error,
            'error',
            isA<PaperlessApiException>(),
          ),
        ),
      );
    });
  });
}
