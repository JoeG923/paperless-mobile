import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hive_ce/hive.dart';
import 'package:paperless_mobile/core/database/hive/hive_config.dart';
import 'package:paperless_mobile/core/database/tables/global_settings.dart';
import 'package:paperless_mobile/core/security/trusted_certificate_pin.dart';

class TrustedCertificateStore {
  const TrustedCertificateStore._();

  static final Map<String, TrustedCertificatePin> _lastUntrustedPins = {};

  static bool isCertificateTrusted(
    X509Certificate certificate,
    String host,
    int port,
  ) {
    final settings = _getSettings();
    if (settings == null) {
      return false;
    }
    final hostPort = canonicalHostPort(host, port);
    final fingerprint = fingerprintSha256FromBytes(certificate.der);
    return settings.trustedCertificatePins.any((pin) {
      final isFingerprintMatch =
          pin.hostPort == hostPort && pin.fingerprintSha256 == fingerprint;
      if (!isFingerprintMatch) {
        return false;
      }

      return isPinWithinValidity(pin);
    });
  }

  static bool isPinWithinValidity(TrustedCertificatePin pin, {DateTime? now}) {
    final current = now ?? DateTime.now();
    // A previously trusted certificate is no longer accepted once it is
    // outside its validity window.
    return !current.isBefore(pin.startValidity) &&
        !current.isAfter(pin.endValidity);
  }

  static TrustedCertificatePin? getLastUntrustedPinForUri(Uri uri) {
    final hostPort = canonicalHostPortFromUri(uri);
    return _lastUntrustedPins[hostPort];
  }

  static TrustedCertificatePin? getTrustedPinForUri(Uri uri) {
    final hostPort = canonicalHostPortFromUri(uri);
    return getTrustedPinForHostPort(hostPort);
  }

  static TrustedCertificatePin? getTrustedPinForHostPort(String hostPort) {
    final settings = _getSettings();
    if (settings == null) {
      return null;
    }
    return settings.trustedCertificatePins
        .cast<TrustedCertificatePin?>()
        .firstWhere((pin) => pin?.hostPort == hostPort, orElse: () => null);
  }

  static List<TrustedCertificatePin> getTrustedPins() {
    final settings = _getSettings();
    return settings?.trustedCertificatePins ?? const [];
  }

  static void rememberUntrustedCertificate(
    X509Certificate certificate,
    String host,
    int port,
  ) {
    final pin = buildPin(certificate, host, port, addedAt: DateTime.now());
    _lastUntrustedPins[pin.hostPort] = pin;
  }

  static Future<bool> trustLastUntrustedForUri(Uri uri) async {
    final pin = getLastUntrustedPinForUri(uri);
    if (pin == null) {
      return false;
    }
    await trustPin(pin);
    return true;
  }

  static Future<void> trustPin(TrustedCertificatePin pin) async {
    final settings = _getSettings();
    if (settings == null) {
      return;
    }
    settings.trustedCertificatePins = [
      ...settings.trustedCertificatePins.where(
        (existing) => existing.hostPort != pin.hostPort,
      ),
      pin,
    ];
    await settings.save();
  }

  static Future<void> removeTrustedPin(TrustedCertificatePin pin) async {
    final settings = _getSettings();
    if (settings == null) {
      return;
    }
    settings.trustedCertificatePins = [
      ...settings.trustedCertificatePins.where(
        (existing) =>
            existing.hostPort != pin.hostPort ||
            existing.fingerprintSha256 != pin.fingerprintSha256,
      ),
    ];
    await settings.save();
  }

  static TrustedCertificatePin buildPin(
    X509Certificate certificate,
    String host,
    int port, {
    DateTime? addedAt,
  }) {
    return TrustedCertificatePin(
      hostPort: canonicalHostPort(host, port),
      fingerprintSha256: fingerprintSha256FromBytes(certificate.der),
      subject: certificate.subject,
      issuer: certificate.issuer,
      startValidity: certificate.startValidity,
      endValidity: certificate.endValidity,
      addedAt: addedAt ?? DateTime.now(),
    );
  }

  static String fingerprintSha256FromBytes(Uint8List bytes) {
    final digest = sha256.convert(bytes);
    return _toHex(digest.bytes);
  }

  static String canonicalHostPortFromUri(Uri uri) {
    final port = uri.hasPort ? uri.port : _defaultPortForScheme(uri.scheme);
    return canonicalHostPort(uri.host, port);
  }

  static String canonicalHostPort(String host, int port) {
    return '${host.toLowerCase()}:$port';
  }

  static int _defaultPortForScheme(String scheme) {
    return scheme.toLowerCase() == 'https' ? 443 : 80;
  }

  static GlobalSettings? _getSettings() {
    if (!Hive.isBoxOpen(HiveBoxes.globalSettings)) {
      return null;
    }
    final box = Hive.box<GlobalSettings>(HiveBoxes.globalSettings);
    if (!box.hasValue) {
      return null;
    }
    return box.getValue();
  }

  static String _toHex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
