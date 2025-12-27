import 'package:hive_ce/hive.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';

part 'trusted_certificate_pin.g.dart';

@HiveType(typeId: HiveTypeIds.trustedCertificatePin)
class TrustedCertificatePin {
  @HiveField(0)
  final String hostPort;
  @HiveField(1)
  final String fingerprintSha256;
  @HiveField(2)
  final String subject;
  @HiveField(3)
  final String issuer;
  @HiveField(4)
  final DateTime startValidity;
  @HiveField(5)
  final DateTime endValidity;
  @HiveField(6)
  final DateTime addedAt;

  TrustedCertificatePin({
    required this.hostPort,
    required this.fingerprintSha256,
    required this.subject,
    required this.issuer,
    required this.startValidity,
    required this.endValidity,
    required this.addedAt,
  });
}
