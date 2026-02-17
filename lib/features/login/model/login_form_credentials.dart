class LoginFormCredentials {
  final String? username;
  final String? password;
  final String? mfaCode;
  final String? apiToken;

  LoginFormCredentials({
    this.username,
    this.password,
    this.mfaCode,
    this.apiToken,
  });

  bool get hasApiToken => apiToken?.trim().isNotEmpty ?? false;

  LoginFormCredentials copyWith({
    String? username,
    String? password,
    String? mfaCode,
    String? apiToken,
  }) {
    return LoginFormCredentials(
      username: username ?? this.username,
      password: password ?? this.password,
      mfaCode: mfaCode ?? this.mfaCode,
      apiToken: apiToken ?? this.apiToken,
    );
  }
}
