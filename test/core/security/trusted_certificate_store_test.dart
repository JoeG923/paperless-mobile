import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_mobile/core/security/trusted_certificate_store.dart';

class _TestCertificate implements X509Certificate {
  @override
  final Uint8List der;
  @override
  String get subject => 'CN=example';
  @override
  String get issuer => 'CN=test';
  @override
  final DateTime startValidity;
  @override
  final DateTime endValidity;

  _TestCertificate({
    required this.der,
    DateTime? startValidity,
    DateTime? endValidity,
  }) : startValidity = startValidity ?? DateTime(2024, 1, 1),
       endValidity = endValidity ?? DateTime(2026, 1, 1);

  @override
  String get pem => '';

  @override
  Uint8List get sha1 => Uint8List(0);
}

void main() {
  test('canonicalHostPortFromUri uses https default port', () {
    final uri = Uri.parse('https://example.com');
    expect(
      TrustedCertificateStore.canonicalHostPortFromUri(uri),
      'example.com:443',
    );
  });

  test('canonicalHostPortFromUri uses explicit port', () {
    final uri = Uri.parse('https://example.com:8443');
    expect(
      TrustedCertificateStore.canonicalHostPortFromUri(uri),
      'example.com:8443',
    );
  });

  test('canonicalHostPort lowercases host', () {
    expect(
      TrustedCertificateStore.canonicalHostPort('Example.COM', 443),
      'example.com:443',
    );
  });

  test('fingerprintSha256FromBytes returns expected hex', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final expected = sha256
        .convert(bytes)
        .bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    expect(TrustedCertificateStore.fingerprintSha256FromBytes(bytes), expected);
  });

  test('buildPin uses canonical host and computed fingerprint', () {
    final cert = _TestCertificate(der: Uint8List.fromList([9, 8, 7]));
    final pin = TrustedCertificateStore.buildPin(cert, 'Example.COM', 443);
    expect(pin.hostPort, 'example.com:443');
    expect(
      pin.fingerprintSha256,
      TrustedCertificateStore.fingerprintSha256FromBytes(cert.der),
    );
  });

  test(
    'isPinWithinValidity returns true within certificate validity window',
    () {
      final pin = TrustedCertificateStore.buildPin(
        _TestCertificate(
          der: Uint8List.fromList([1, 2, 3, 4]),
          startValidity: DateTime(2024, 1, 1),
          endValidity: DateTime(2026, 1, 1),
        ),
        'example.com',
        443,
      );

      expect(
        TrustedCertificateStore.isPinWithinValidity(
          pin,
          now: DateTime(2025, 6, 1),
        ),
        isTrue,
      );
    },
  );

  test('isPinWithinValidity returns false after certificate expiration', () {
    final pin = TrustedCertificateStore.buildPin(
      _TestCertificate(
        der: Uint8List.fromList([4, 3, 2, 1]),
        startValidity: DateTime(2024, 1, 1),
        endValidity: DateTime(2025, 1, 1),
      ),
      'example.com',
      443,
    );

    expect(
      TrustedCertificateStore.isPinWithinValidity(
        pin,
        now: DateTime(2025, 1, 2),
      ),
      isFalse,
    );
  });
}
