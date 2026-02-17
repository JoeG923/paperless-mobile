class PaperlessFormValidationException implements Exception {
  final Map<String, String> validationMessages;

  PaperlessFormValidationException(this.validationMessages);

  bool hasMessageForField(String formKey) {
    return validationMessages.containsKey(formKey);
  }

  bool hasUnspecificErrorMessage() {
    return validationMessages.containsKey("non_field_errors");
  }

  String? unspecificErrorMessage() {
    return validationMessages["non_field_errors"];
  }

  String? messageForField(String formKey) {
    return validationMessages[formKey];
  }

  static bool canParse(dynamic json) {
    if (json is Map<String, dynamic>) {
      return json.values.every(
        (element) => element is String || element is List,
      );
    }
    return false;
  }

  factory PaperlessFormValidationException.fromJson(Map<String, dynamic> json) {
    final Map<String, String> validationMessages = {};
    for (final entry in json.entries) {
      if (entry.value is List) {
        validationMessages.putIfAbsent(
          entry.key,
          () => (entry.value as List).first as String,
        );
      } else if (entry.value is String) {
        validationMessages.putIfAbsent(entry.key, () => entry.value);
      } else {
        validationMessages.putIfAbsent(entry.key, () => entry.value.toString());
      }
    }
    return PaperlessFormValidationException(validationMessages);
  }
}
