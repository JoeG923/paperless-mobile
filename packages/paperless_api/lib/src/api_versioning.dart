const paperlessApiVersionOverrideExtraKey = 'paperless_api_version_override';

/// Marks a single request as needing a specific Paperless API version.
///
/// The app-level interceptor still clamps this to the version supported by the
/// connected server and this client.
Map<String, Object?> paperlessApiVersionExtra(int apiVersion) {
  return {paperlessApiVersionOverrideExtraKey: apiVersion};
}
