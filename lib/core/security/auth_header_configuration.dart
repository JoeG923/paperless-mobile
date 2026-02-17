import 'dart:io';

class AuthHeaderConfiguration {
  static final RegExp _headerNamePattern = RegExp(r'^[A-Za-z0-9-]+$');
  static final RegExp _unsafeHeaderValueChars = RegExp(r'[\x00-\x1F\x7F]');

  final String headerName;
  final String? valuePrefix;

  const AuthHeaderConfiguration({
    this.headerName = HttpHeaders.authorizationHeader,
    this.valuePrefix = 'Token',
  });

  const AuthHeaderConfiguration.standard()
    : this(headerName: HttpHeaders.authorizationHeader, valuePrefix: 'Token');

  const AuthHeaderConfiguration.bearer()
    : this(headerName: HttpHeaders.authorizationHeader, valuePrefix: 'Bearer');

  String format(String token) {
    final normalizedToken = sanitizeHeaderValue(token);
    final prefix = valuePrefix == null
        ? null
        : sanitizeHeaderValue(valuePrefix!);
    if (normalizedToken.isEmpty) {
      return '';
    }
    if (prefix == null || prefix.isEmpty) {
      return normalizedToken;
    }
    return '$prefix $normalizedToken';
  }

  static bool isValidHeaderName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return _headerNamePattern.hasMatch(normalized);
  }

  static String sanitizeHeaderValue(String value) =>
      value.replaceAll(_unsafeHeaderValueChars, '').trim();
}
