# 4.0.0+400
**Server/API compatibility**
- Updated to Paperless-ngx API v9 and added global API version negotiation headers.
- Fixed authentication for non-admin users and improved optional MFA handling.
- Documents now request full permissions (`full_perms`) so the Permissions tab is accurate.
- Expanded bulk operations (reprocess, rotate, split, delete pages, merge) with improved feedback.
- Added task tracking UI and fixed tasks endpoint handling.

**Security**
- Enforced TLS validation for trusted certificates, self-signed certs require explicit approval.
- Added trusted certificate management with fingerprinting and change warnings.

**Scanning & upload**
- Modernized document scanner (ML Kit) with multi-page capture and auto-cropping.
- Added upload presets (title template, date, labels/tags/storage path) with auto-save.
- Uploads now hook into server task tracking when available.
- Added upload timeout and cancel support with clear error messaging.
- Improved error mapping for timeouts, cancellations, and unreachable servers.
- Added a warning when server task tracking is unavailable after upload.

**UI stability & fixes**
- Responsive scan grid layout for larger screens.
- Fixed disabled actions showing offline messages.
- Fixed document details tab layout crashes and improved permissions display.
- Hardened document list rendering against missing labels/tags.
- Fixed login screen safe-area overlap so App Logs is accessible.

**Platform/build**
- Updated Android build targets (compile/target SDK 36, min SDK 24) and Kotlin tooling.
