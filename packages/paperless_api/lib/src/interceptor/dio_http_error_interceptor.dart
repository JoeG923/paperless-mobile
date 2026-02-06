import 'package:dio/dio.dart';
import 'package:paperless_api/paperless_api.dart';

class DioHttpErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode != 400) {
      handler.next(err);
      return;
    }

    final data = err.response!.data;
    if (PaperlessServerMessageException.canParse(data)) {
      final exception = PaperlessServerMessageException.fromJson(data);
      final message = exception.detail;
      handler.reject(
        DioException(
          message: message,
          requestOptions: err.requestOptions,
          error: exception,
          response: err.response,
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }

    if (PaperlessFormValidationException.canParse(data)) {
      final exception = PaperlessFormValidationException.fromJson(data);
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: exception,
          response: err.response,
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }

    if (data is String) {
      if (data.contains("No required SSL certificate was sent")) {
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            type: DioExceptionType.badResponse,
            error: const PaperlessApiException(
              ErrorCode.missingClientCertificate,
            ),
          ),
        );
        return;
      }

      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          message: data,
          error: PaperlessApiException(
            ErrorCode.documentLoadFailed,
            details: data,
          ),
          response: err.response,
          stackTrace: err.stackTrace,
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }

    handler.next(err);
  }
}
