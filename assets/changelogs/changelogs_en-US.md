# 4.0.0
**Paperless-ngx API compatibility**
- Updated the client from the old API v8 integration to Paperless-ngx API v9 for current v2 servers.
- Added automatic API negotiation so Paperless-ngx v2 uses API v9 and Paperless-ngx v3 uses API v10.
- Added API v10 support based on the Paperless-ngx v3 beta API surface.
- Updated search/filter request handling for the API v9/v10 contract.
- Updated labels, tasks, document permissions, and server statistics handling for newer Paperless-ngx responses.

**Paperless-ngx v3 support**
- Added Paperless-ngx v3 document list, inbox, statistics, permissions, and task compatibility.
- Added first-class server-side AI entry points when a Paperless-ngx v3 server exposes them.
- Added AI chat, document-scoped chat, metadata suggestions, and AI status screens.
- AI features are hidden automatically on Paperless-ngx v2, API v9, and v3 servers without AI enabled.

**Authentication and accounts**
- Improved login for current Paperless-ngx servers, including non-admin accounts.
- Fixed MFA code submission and invalid-code handling so failed MFA attempts return to the form instead of getting stuck.
- Improved account/session migration for the newer API version selection.
- Fixed login screen safe-area layout so App Logs stays accessible on devices with gesture navigation.

**Scanning and upload**
- Replaced the old scanner integration with Google ML Kit Document Scanner.
- Added multi-page capture, automatic crop handling, and a responsive scan grid.
- Added upload presets for title templates, dates, labels/tags, storage paths, and related metadata.
- Added upload auto-save behavior for repeated scanner workflows.
- Added upload timeout and cancel support.
- Improved upload error messages for timeouts, cancellations, unreachable servers, and server-side failures.
- Uploads now link to server task tracking when the server provides task information.
- Added task-status feedback after uploads and clear messaging when task tracking is unavailable.

**Documents and workflow**
- Expanded bulk document operations, including reprocess, rotate, split, delete pages, and merge.
- Documents now request full permission data (`full_perms`) so the Permissions tab is accurate.
- Improved document details, edit, search, linked-document, similar-document, and task screens for newer server data.
- Hardened document list and document cards against missing labels, tags, and optional fields.
- Fixed disabled document actions incorrectly reporting offline state.

**Security and certificates**
- Enforced normal TLS validation for trusted certificates.
- Self-signed or otherwise untrusted certificates now require explicit user approval.
- Added trusted-certificate storage with fingerprint display.
- Added warnings when a trusted server certificate changes.
- Redacted sensitive authentication and request data from app logs.

**UI refresh**
- Refreshed the app with a Material 3 design while keeping the existing navigation model familiar.
- Updated Home, Documents, Search, Inbox, Scanner, Upload, Details, Edit, Tasks, and related screens.
- Improved empty, loading, and error states across the app.
- Improved larger-screen layouts and scanner action placement.
- Fixed crashes and layout failures in the inbox, statistics, permissions, and document details views.

**Platform and maintenance**
- Updated Android compile/target SDK to 36 and min SDK to 24.
- Updated Kotlin, Android Gradle, Flutter, and maintained app dependencies.
- Removed or replaced abandoned scanner dependencies.
- Added broader unit, widget, integration, and temporary Paperless-ngx server test coverage for API v9/v10 behavior, login/MFA, documents, scanner upload, and AI availability.
