class LoginFormCredentials {
  final String? username;
  final String? password;
  final String? mfaCode;

  LoginFormCredentials({this.username, this.password, this.mfaCode});

  LoginFormCredentials copyWith({
    String? username,
    String? password,
    String? mfaCode,
  }) {
    return LoginFormCredentials(
      username: username ?? this.username,
      password: password ?? this.password,
      mfaCode: mfaCode ?? this.mfaCode,
    );
  }
}
