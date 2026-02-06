(String username, String obscuredUrl) splitRedactUserId(String userId) {
  final parts = userId.split('@');
  if (parts.length != 2) {
    return ('unknown', 'unknown');
  }

  final username = parts.first;
  final serverUrl = parts.last;
  final uri = Uri.tryParse(serverUrl);
  final host = uri?.host;
  if (host == null || host.isEmpty) {
    return (username, 'unknown');
  }

  final obscuredUrl = switch (host.length) {
    <= 2 => '${host[0]}***',
    <= 4 => '${host.substring(0, 1)}***${host.substring(host.length - 1)}',
    _ => '${host.substring(0, 2)}***${host.substring(host.length - 2)}',
  };
  return (username, obscuredUrl);
}

String redactUserId(String userId) {
  final (username, obscuredUrl) = splitRedactUserId(userId);
  return '$username@$obscuredUrl';
}
