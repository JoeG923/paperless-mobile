import 'package:json_annotation/json_annotation.dart';

class LocalDateTimeJsonConverter extends JsonConverter<DateTime, String> {
  const LocalDateTimeJsonConverter();

  @override
  DateTime fromJson(String json) {
    final trimmed = json.trim();
    final isDateOnly =
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed);
    if (isDateOnly) {
      final parts = trimmed.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }
    return DateTime.parse(json).toLocal();
  }

  @override
  String toJson(DateTime object) {
    return object.toUtc().toIso8601String();
  }
}
