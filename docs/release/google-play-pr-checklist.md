# Google Play PR Checklist

This checklist separates repository changes that belong in the PR from Play Console work that must be completed by the app owner.

## Included in Git

- Android package id remains `de.astubenbord.paperless_mobile` so v4 can upgrade existing Paperless Mobile installs.
- Version is `4.0.0+4060`, which is above the original v3.2.1 split APK build codes.
- Release app label is `Paperless Mobile`; debug builds default to `Paperless Mobile Debug`.
- Android target SDK is 36 and min SDK is 24.
- Broad media storage permissions are explicitly removed in the manifest.
- Store descriptions and release notes describe paperless-ngx v2/v3 compatibility, scanner/upload fixes, task tracking, trusted certificate handling, and optional Paperless-ngx v3 AI features.

## Owner Actions Before Play Submission

- Sign the Android App Bundle with the same Play App Signing lineage used by the existing listing.
- Confirm the highest version code ever uploaded to Play Console. If any uploaded artifact is newer than `4060`, bump `pubspec.yaml` before release.
- Build and upload a release AAB, not a debug APK.
- Publish or confirm a public privacy policy URL in Play Console.
- Update the Play Console Data Safety form.
- Update screenshots and store listing copy if the current listing still reflects the abandoned v3 UI.
- Run an internal or closed testing rollout before production.
- Re-run the full Android test set against temporary paperless-ngx v2 and v3 servers from a clean checkout.

## Data Safety Review Notes

- This app is a client for a user-configured paperless-ngx server.
- Server URLs, credentials, scanned documents, document metadata, search queries, prompts, and document context are used for app functionality.
- Documents and scans are uploaded to the user-configured paperless-ngx server, not to the app developer.
- Optional AI prompts and document context are sent to the user-configured Paperless-ngx v3 server only when server-side AI features are enabled.
- Google ML Kit Document Scanner is used for scanning. Google documents that input and output data is processed on-device, while Google Play services may contact Google for model downloads, fixes, abuse detection, and compatibility checks.
- Credentials and tokens are stored through the app's secure storage path where supported, and Android backups are disabled.
- No advertising, analytics, or crash reporting SDKs were found in the repository during this review.

## Policy References

- Target API requirements: https://developer.android.com/google/play/requirements/target-sdk
- Play sensitive permissions policy: https://support.google.com/googleplay/android-developer/answer/16558241
- Play Data Safety form: https://support.google.com/googleplay/android-developer/answer/10787469
- Play release notes limits: https://support.google.com/googleplay/android-developer/answer/9859348
- ML Kit terms: https://developers.google.com/ml-kit/terms
- ML Kit Document Scanner: https://developers.google.com/ml-kit/vision/doc-scanner
