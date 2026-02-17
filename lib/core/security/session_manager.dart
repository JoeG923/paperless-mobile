import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:paperless_mobile/core/security/auth_header_configuration.dart';
import 'package:paperless_mobile/features/login/model/client_certificate.dart';

abstract interface class SessionManager implements ChangeNotifier {
  Dio get client;

  void updateSettings({
    String? baseUrl,
    String? authToken,
    ClientCertificate? clientCertificate,
    AuthHeaderConfiguration? authHeaderConfiguration,
  });
  void resetSettings();
}
