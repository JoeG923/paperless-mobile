const paperlessApiVersionOverrideExtraKey = 'paperless_api_version_override';

Map<String, Object?> paperlessApiVersionExtra(int apiVersion) {
  return {paperlessApiVersionOverrideExtraKey: apiVersion};
}
