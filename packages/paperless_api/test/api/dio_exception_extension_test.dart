import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_api/src/extensions/dio_exception_extension.dart';

void main() {
  test('unravel maps timeout exceptions to requestTimedOut', () {
    final exception = DioException(
      requestOptions: RequestOptions(path: '/'),
      type: DioExceptionType.sendTimeout,
    );

    final result = exception.unravel();

    expect(result, isA<PaperlessApiException>());
    expect((result as PaperlessApiException).code, ErrorCode.requestTimedOut);
  });

  test('unravel maps cancel exceptions to requestCancelled', () {
    final exception = DioException(
      requestOptions: RequestOptions(path: '/'),
      type: DioExceptionType.cancel,
    );

    final result = exception.unravel();

    expect(result, isA<PaperlessApiException>());
    expect((result as PaperlessApiException).code, ErrorCode.requestCancelled);
  });

  test('unravel maps socket exceptions to serverUnreachable', () {
    final exception = DioException(
      requestOptions: RequestOptions(path: '/'),
      type: DioExceptionType.unknown,
      error: const SocketException('Host unreachable'),
    );

    final result = exception.unravel();

    expect(result, isA<PaperlessApiException>());
    expect((result as PaperlessApiException).code, ErrorCode.serverUnreachable);
  });
}
