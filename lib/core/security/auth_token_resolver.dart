import 'package:paperless_mobile/core/security/auth_header_configuration.dart';

class ResolvedAuthToken {
  final String token;
  final AuthHeaderConfiguration authHeaderConfiguration;

  const ResolvedAuthToken({
    required this.token,
    required this.authHeaderConfiguration,
  });
}

ResolvedAuthToken resolveAuthToken(
  String rawToken, {
  String? usernameFallback,
}) {
  final normalized = rawToken.trim();
  final schemeMatch = RegExp(
    r'^(Bearer|Token|X-API-KEY)\s+(.+)$',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (schemeMatch != null) {
    final scheme = schemeMatch.group(1)!.toLowerCase();
    final token = AuthHeaderConfiguration.sanitizeHeaderValue(
      schemeMatch.group(2)!,
    );
    if (token.isNotEmpty) {
      return switch (scheme) {
        'bearer' => ResolvedAuthToken(
          token: token,
          authHeaderConfiguration: const AuthHeaderConfiguration.bearer(),
        ),
        'x-api-key' => ResolvedAuthToken(
          token: token,
          authHeaderConfiguration: const AuthHeaderConfiguration(
            headerName: 'x-api-key',
            valuePrefix: null,
          ),
        ),
        _ => ResolvedAuthToken(
          token: token,
          authHeaderConfiguration: const AuthHeaderConfiguration.standard(),
        ),
      };
    }
  }

  final explicitHeaderMatch = RegExp(
    r'^([A-Za-z0-9-]+)\s*:\s*(.*)$',
  ).firstMatch(normalized);
  if (explicitHeaderMatch != null) {
    final headerName = explicitHeaderMatch.group(1)!.trim().toLowerCase();
    var token = AuthHeaderConfiguration.sanitizeHeaderValue(
      explicitHeaderMatch.group(2)!,
    );
    if (token.isEmpty) {
      token = AuthHeaderConfiguration.sanitizeHeaderValue(
        usernameFallback ?? '',
      );
    }
    if (AuthHeaderConfiguration.isValidHeaderName(headerName)) {
      return ResolvedAuthToken(
        token: token,
        authHeaderConfiguration: AuthHeaderConfiguration(
          headerName: headerName,
          valuePrefix: null,
        ),
      );
    }
  }

  final fallbackToken = AuthHeaderConfiguration.sanitizeHeaderValue(normalized);
  return ResolvedAuthToken(
    token: fallbackToken,
    authHeaderConfiguration: const AuthHeaderConfiguration.standard(),
  );
}
