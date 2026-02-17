enum CustomFieldDataType {
  string('string'),
  boolean('boolean'),
  date('date'),
  url('url'),
  integer('integer'),
  float('float'),
  monetary('monetary'),
  documentLink('documentlink'),
  select('select'),
  longText('longtext');

  final String wireValue;

  const CustomFieldDataType(this.wireValue);

  static CustomFieldDataType fromWireValue(String raw) {
    final normalized = raw.trim().toLowerCase();
    return switch (normalized) {
      // Backward compatibility for older client mappings.
      'text' => CustomFieldDataType.string,
      'number' => CustomFieldDataType.float,
      _ => CustomFieldDataType.values.firstWhere(
        (value) => value.wireValue == normalized,
        orElse: () => CustomFieldDataType.string,
      ),
    };
  }
}
