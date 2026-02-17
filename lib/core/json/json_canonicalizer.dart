import 'dart:convert';

String? canonicalizeJsonString(String? jsonString) {
  if (jsonString == null) {
    return null;
  }
  final trimmed = jsonString.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(trimmed);
    final normalized = _canonicalizeJsonValue(decoded);
    return jsonEncode(normalized);
  } catch (_) {
    return trimmed;
  }
}

Object? _canonicalizeJsonValue(Object? value) {
  if (value is List) {
    return value.map(_canonicalizeJsonValue).toList(growable: false);
  }
  if (value is Map) {
    final entries =
        value.entries
            .map(
              (entry) => MapEntry(
                entry.key.toString(),
                _canonicalizeJsonValue(entry.value),
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.key.compareTo(b.key));
    return {for (final entry in entries) entry.key: entry.value};
  }
  return value;
}
