import 'dart:io';

import 'package:dio/dio.dart';
import 'package:paperless_api/src/models/paperless_api_exception.dart';

extension DioExceptionUnravelExtension on DioException {
  Object unravel({Object? orElse}) {
    final innerError = error;
    if (innerError is PaperlessApiException) {
      return innerError;
    }
    if (type == DioExceptionType.cancel) {
      return const PaperlessApiException(ErrorCode.requestCancelled);
    }
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout) {
      return PaperlessApiException(
        ErrorCode.requestTimedOut,
        details: message,
        stackTrace: stackTrace,
      );
    }
    if (innerError is SocketException) {
      return PaperlessApiException(
        ErrorCode.serverUnreachable,
        details: innerError.message,
        stackTrace: stackTrace,
      );
    }
    return innerError ?? orElse ?? Exception("Unknown");
  }
}
