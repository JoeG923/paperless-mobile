import 'package:dio/dio.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_api/src/extensions/dio_exception_extension.dart';

class PaperlessAuthenticationApiImpl implements PaperlessAuthenticationApi {
  final Dio client;
  static const List<String> _tokenEndpoints = <String>[
    '/api/token/',
    '/api/token',
    '/api/auth/token/',
  ];

  PaperlessAuthenticationApiImpl(this.client);

  @override
  Future<String> login({
    required String username,
    required String password,
    String? code,
  }) async {
    final payload = {
      'username': username,
      'password': password,
      if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
    };

    for (var i = 0; i < _tokenEndpoints.length; i++) {
      final endpoint = _tokenEndpoints[i];
      try {
        final response = await client.post(
          endpoint,
          data: payload,
          options: Options(
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
            followRedirects: false,
            headers: {'Accept': 'application/json'},
          ),
        );
        final token = _extractToken(response.data);
        if (token != null) {
          return token;
        }
      } on DioException catch (exception) {
        final isLastEndpoint = i == _tokenEndpoints.length - 1;
        if (!isLastEndpoint && _shouldTryNextEndpoint(exception)) {
          continue;
        }
        throw exception.unravel();
      } catch (error, stackTrace) {
        throw PaperlessApiException.unknown(
          details: error.toString(),
          stackTrace: stackTrace,
        );
      }
    }
    throw const PaperlessApiException.unknown(
      details: 'Could not resolve authentication token from response.',
    );
  }

  bool _shouldTryNextEndpoint(DioException exception) {
    final statusCode = exception.response?.statusCode;
    return statusCode == 404 || statusCode == 405;
  }

  String? _extractToken(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final resolvedToken =
        (data['token'] ?? data['access'] ?? data['key'] ?? data['auth_token'])
            ?.toString()
            .trim();
    if (resolvedToken == null || resolvedToken.isEmpty) {
      return null;
    }
    return resolvedToken;
  }
}
