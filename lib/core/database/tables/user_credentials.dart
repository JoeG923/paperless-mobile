import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/features/login/model/client_certificate.dart';

part 'user_credentials.g.dart';

@HiveType(typeId: HiveTypeIds.localUserCredentials)
class UserCredentials extends HiveObject {
  @HiveField(0)
  final String token;
  @HiveField(1)
  final ClientCertificate? clientCertificate;
  @HiveField(2, defaultValue: HttpHeaders.authorizationHeader)
  final String authHeaderName;
  @HiveField(3, defaultValue: 'Token')
  final String? authHeaderValuePrefix;

  UserCredentials({
    required this.token,
    this.clientCertificate,
    this.authHeaderName = HttpHeaders.authorizationHeader,
    this.authHeaderValuePrefix = 'Token',
  });
}
