import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/interceptor/api_version_interceptor.dart';
import 'package:paperless_mobile/core/interceptor/dio_offline_interceptor.dart';
import 'package:paperless_mobile/core/interceptor/dio_unauthorized_interceptor.dart';
import 'package:paperless_mobile/core/interceptor/retry_on_connection_change_interceptor.dart';
import 'package:paperless_mobile/core/security/session_manager.dart';
import 'package:paperless_mobile/core/security/trusted_certificate_store.dart';
import 'package:paperless_mobile/features/login/model/client_certificate.dart';

/// Manages the security context, authentication and base request URL for
/// an underlying [Dio] client which is injected into all services
/// requiring authenticated access to the Paperless REST API.
class SessionManagerImpl extends ValueNotifier<Dio> implements SessionManager {
  @override
  Dio get client => value;

  SessionManagerImpl([List<Interceptor> interceptors = const []])
      : super(_initDio(interceptors));

  static Dio _initDio(List<Interceptor> interceptors) {
    //en- and decoded by utf8 by default
    final Dio dio = Dio(
      BaseOptions(
        contentType: Headers.jsonContentType,
        followRedirects: true,
        maxRedirects: 10,
      ),
    );
    dio.options
      ..receiveTimeout = const Duration(seconds: 30)
      ..sendTimeout = const Duration(seconds: 60)
      ..responseType = ResponseType.json;
    dio.httpClientAdapter = _buildAdapter();
    dio.interceptors.addAll([
      ...interceptors,
      ApiVersionInterceptor(),
      DioUnauthorizedInterceptor(),
      DioHttpErrorInterceptor(),
      DioOfflineInterceptor(),
      RetryOnConnectionChangeInterceptor(dio: dio)
    ]);
    return dio;
  }

  @override
  void updateSettings({
    String? baseUrl,
    String? authToken,
    ClientCertificate? clientCertificate,
  }) {
    if (clientCertificate != null) {
      final context = SecurityContext()
        ..usePrivateKeyBytes(
          clientCertificate.bytes,
          password: clientCertificate.passphrase,
        )
        ..useCertificateChainBytes(
          clientCertificate.bytes,
          password: clientCertificate.passphrase,
        )
        ..setTrustedCertificatesBytes(
          clientCertificate.bytes,
          password: clientCertificate.passphrase,
        );
      client.httpClientAdapter = _buildAdapter(context: context);
    }

    if (baseUrl != null) {
      client.options.baseUrl = baseUrl;
    }

    if (authToken != null) {
      client.options.headers.addAll({
        HttpHeaders.authorizationHeader: 'Token $authToken',
      });
    }

    notifyListeners();
  }

  @override
  void resetSettings() {
    client.httpClientAdapter = _buildAdapter();
    client.options.baseUrl = '';
    client.options.headers.remove(HttpHeaders.authorizationHeader);
    notifyListeners();
  }

  static IOHttpClientAdapter _buildAdapter({SecurityContext? context}) {
    return IOHttpClientAdapter()
      ..createHttpClient = () => _buildHttpClient(context: context);
  }

  static HttpClient _buildHttpClient({SecurityContext? context}) {
    final client = context == null ? HttpClient() : HttpClient(context: context);
    client.badCertificateCallback = (cert, host, port) {
      TrustedCertificateStore.rememberUntrustedCertificate(cert, host, port);
      return TrustedCertificateStore.isCertificateTrusted(cert, host, port);
    };
    return client;
  }
}
