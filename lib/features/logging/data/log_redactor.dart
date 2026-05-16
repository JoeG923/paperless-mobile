class LogRedactor {
  const LogRedactor._();

  static final _jsonSecretPattern = RegExp(
    r'("(?:access|apiToken|auth_token|keyPassword|password|refresh|storePassword|token)"\s*:\s*")[^"]*(")',
    caseSensitive: false,
  );
  static final _keyValueSecretPattern = RegExp(
    r'\b((?:access|apiToken|auth_token|keyPassword|password|refresh|storePassword|token)\s*[:=]\s*)[^\s,;&}]+',
    caseSensitive: false,
  );
  static final _authHeaderPattern = RegExp(
    r'\b((?:authorization|x-api-key|api-key)\s*[:=]\s*)[^\r\n,}]+',
    caseSensitive: false,
  );
  static final _authSchemePattern = RegExp(
    r'\b(Bearer|Token)\s+[A-Za-z0-9._~+/=-]{8,}',
  );
  static final _querySecretPattern = RegExp(
    r'([?&](?:access|apiToken|auth_token|keyPassword|password|refresh|storePassword|token)=)[^&\s]+',
    caseSensitive: false,
  );

  static String redact(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString().redactForLogs();
  }
}

extension LogRedaction on String {
  String redactForLogs() {
    return replaceAllMapped(
          LogRedactor._jsonSecretPattern,
          (match) => '${match.group(1)}[REDACTED]${match.group(2)}',
        )
        .replaceAllMapped(
          LogRedactor._authHeaderPattern,
          (match) => '${match.group(1)}[REDACTED]',
        )
        .replaceAllMapped(
          LogRedactor._querySecretPattern,
          (match) => '${match.group(1)}[REDACTED]',
        )
        .replaceAllMapped(
          LogRedactor._keyValueSecretPattern,
          (match) => '${match.group(1)}[REDACTED]',
        )
        .replaceAllMapped(
          LogRedactor._authSchemePattern,
          (match) => '${match.group(1)} [REDACTED]',
        );
  }
}
