# Paperless Mobile Rewrite Specification

Date: February 16, 2026  
Branch: `rewrite-spec-modern-client`

## 1. Purpose

Define a rewrite-level plan for a modern, fast, feature-rich Paperless-ngx mobile client that maximizes server capability usage while staying maintainable and reliable.

This spec is implementation-oriented. It is intended to drive backlog creation, sequencing, and acceptance criteria.

## 2. Product Vision

Build the best mobile client for Paperless-ngx, not just a companion app:

- Full-fidelity Paperless workflows on mobile.
- Fast at scale (small and very large document libraries).
- Reliable ingestion and background processing.
- Power-user search and metadata operations without desktop fallback.
- Security and multi-account support suitable for self-hosted and enterprise setups.

## 3. Goals and Non-Goals

### Goals

1. Reach high functional parity with Paperless-ngx API (including newer API capabilities).
2. Improve performance and responsiveness across list, detail, and search flows.
3. Improve correctness and operational reliability (state handling, background jobs, error behavior).
4. Establish maintainable architecture and quality gates for long-term iteration.

### Non-Goals (v1 rewrite)

1. Rebuilding server-side Paperless features in mobile that are admin-only by design.
2. Supporting unsupported legacy mobile OS versions beyond Flutter baseline.
3. Desktop-class reporting/analytics UX beyond focused mobile use cases.

## 4. Current State Summary (Why Rewrite)

The current app already provides strong core flows (scan/upload/search/edit/bulk basics), but has structural limits:

1. Feature parity gaps vs server capabilities (notably custom fields and advanced bulk operations).
2. Scalability risk patterns (large eager loads, repeated reloads, polling-heavy task updates).
3. Mixed state and mutability patterns that raise correctness risk.
4. CI quality gates are release-centric instead of test/lint-centric.
5. UX and localization consistency debt in key operational screens.

## 5. Product Requirements

### 5.1 Core Capability Parity (Must Have)

1. Documents:
   - List, search, view, edit, delete, preview, download, share.
   - Similar documents (`more_like_id`).
   - Notes read/create/update/delete.
   - Permission visibility and permission editing for authorized users.
2. Metadata:
   - Labels (tags, correspondents, document types, storage paths) CRUD as allowed by permissions.
   - Custom fields:
     - View/edit custom field values on documents.
     - Include custom fields in upload flow.
     - Filter/search with custom field query builder.
     - Bulk modify custom fields.
3. Bulk operations:
   - Existing: delete/reprocess/merge/rotate/split/delete pages/tag/label assignment.
   - Add: set permissions, custom field bulk modify, remove password, edit_pdf operation support where feasible.
4. Saved views:
   - Create/edit/delete/preview/use.
   - Correct serialization/deserialization of all supported rules.
5. Ingestion:
   - Scanner capture to upload.
   - External share ingestion queue.
   - Reliable background upload pipeline with retries and cancellation.
   - Task tracking tied to upload UUID lifecycle.
6. Auth/session:
   - Token auth baseline.
   - Optional support path for additional server auth modes if configured (Remote User and OIDC-compatible flows).
7. Security:
   - Biometric gate for account/session.
   - Client certificate auth.
   - Trusted certificate pin management.

### 5.2 Performance and UX (Must Have)

1. Fast startup and route transitions.
2. Smooth large-list browsing (virtualization, image caching, low-jank scrolling).
3. Search UX with instant feedback and resilient offline/poor network behavior.
4. Tablet and large-screen adaptive layouts for productivity-heavy pages.
5. Consistent localization coverage (no hardcoded English in production screens).

### 5.3 Reliability and Operability (Must Have)

1. Deterministic state updates without hidden mutable side effects.
2. Strong error mapping and user-safe recovery paths.
3. Structured telemetry and logs for upload/task/search flows.
4. Test coverage focused on critical behavior and regression prevention.

## 6. Architecture Blueprint

### 6.1 High-Level Architecture

1. App Layer:
   - Navigation shell, account/session context, feature flag controls.
2. Domain Layer:
   - Use-cases for document operations, ingest pipeline, task lifecycle, search/filter composition.
3. Data Layer:
   - API client(s), local database/cache, sync orchestration.
4. Platform Layer:
   - Scanner integration, notifications, secure storage, file I/O, biometrics.

### 6.2 Data Strategy (Local-First with Sync)

1. Local store (SQLite/Drift or equivalent) for:
   - Document list snapshots.
   - Label catalogs.
   - Upload/task queue state.
   - Saved search metadata and search history.
2. Stale-while-revalidate pattern:
   - Render cached state immediately.
   - Refresh incrementally from server.
3. Explicit invalidation rules:
   - Targeted cache updates for document/label changes.
   - Avoid full-list invalidation by default.

### 6.3 API Strategy

1. Move to schema-driven API client generation from Paperless OpenAPI schema.
2. Keep a thin compatibility adapter for:
   - API version negotiation.
   - Minor response shape differences.
3. Standardize error mapping from transport -> domain errors -> UI actions.

### 6.4 State Management Strategy

1. Choose one primary state model (Bloc or equivalent), avoid mixed paradigms per feature.
2. Enforce immutable state updates.
3. Centralize side effects in use-case/interactor layer, not widgets.

### 6.5 Background Execution

1. Background upload worker with persisted queue.
2. Retry policy:
   - Exponential backoff.
   - Retry classes by error type (network, auth, server validation).
3. Task observer:
   - Adaptive polling (interval/backoff) instead of fixed high-frequency polling per task.
   - Batched refresh where possible.

## 7. Feature Design Requirements

### 7.1 Search and Filter Builder

1. Support full-text query modes and advanced rules.
2. Add custom field filter builder mapped to `custom_field_query`.
3. Maintain exact round-trip behavior between saved view filter rules and runtime filters.
4. Expose clear query chips/tokens with edit/remove interactions.

### 7.2 Document Edit and Details

1. Include custom fields section with type-aware editors.
2. Preserve notes and permissions workflows.
3. Add user-visible permission editing for authorized users.
4. Keep quick actions reachable (download/share/open/print/edit).

### 7.3 Ingestion Experience

1. Single entrypoint for all ingestion sources (scanner, files, share intents).
2. Upload preparation screen:
   - Include labels, ASN, created date, custom fields.
   - Preset support for repeated workflows.
3. Background mode:
   - Progress visibility.
   - Resume after app restart.

## 8. Quality Gates and Metrics

### 8.1 Performance Targets

1. Cold startup to interactive: <= 2.5s on reference mid-tier Android device.
2. Document list scroll: >= 55 FPS p95 on 5k+ document libraries.
3. Search response UI update: <= 300ms after server response for top-level rendering.

### 8.2 Reliability Targets

1. Crash-free sessions: >= 99.8%.
2. Upload success rate (non-validation failures): >= 99%.
3. Task sync correctness (final status reflected): >= 99.5%.

### 8.3 Test and CI Targets

1. Required CI checks on PR:
   - Static analysis/lint.
   - Unit tests.
   - API contract tests.
   - Critical-path integration tests (auth, list/search, upload, task completion).
2. Release workflows depend on passing quality workflows.

## 9. Migration and Delivery Plan

### 9.1 Migration Strategy

1. Strangler pattern:
   - Replace feature slices incrementally behind stable routes.
2. Compatibility window:
   - Keep old and new implementations for selected features under flags until validation.
3. Data migration:
   - Introduce new local DB schema.
   - One-time migration for account/session and critical user preferences.

### 9.2 Phased Milestones

#### Phase 0: Foundations (2-3 weeks)

1. Finalize architecture and coding standards.
2. Set up generated API client pipeline.
3. Add CI quality gates.
4. Define telemetry and error taxonomy.

Acceptance:
1. CI gates block merges on failure.
2. Generated client builds and basic authenticated calls pass.

#### Phase 1: Core Data + Navigation Shell (3-4 weeks)

1. New app shell and account/session context.
2. Local DB and repository abstraction.
3. Document list baseline with pagination and caching.

Acceptance:
1. Multi-account login/switch/restore works.
2. Document list supports online refresh and cached startup.

#### Phase 2: Search + Details + Edit (4-5 weeks)

1. Search UI and advanced filter builder.
2. Document details and edit flows.
3. Notes and permissions display/edit.
4. Custom fields read/edit support.

Acceptance:
1. Filter round-trip with saved views is correct.
2. Custom field edits persist and are reflected in detail/list views.

#### Phase 3: Ingestion + Task Pipeline (4-5 weeks)

1. Scanner and share-ingest rewrite.
2. Persisted background upload queue.
3. Adaptive task observer and notifications.
4. Upload presets including custom fields.

Acceptance:
1. Upload survives app restart/network interruption.
2. Task completion updates and deep-links to created document.

#### Phase 4: Bulk Ops + Parity Completion (3-4 weeks)

1. Advanced bulk operations parity completion.
2. Custom field bulk modifications.
3. Permission bulk operations where API/UX permits.

Acceptance:
1. Bulk operation matrix passes integration tests against Paperless test server.

#### Phase 5: Hardening + Beta (2-3 weeks)

1. Performance tuning and memory profiling.
2. Localization and accessibility completion.
3. Beta rollout, telemetry review, release readiness.

Acceptance:
1. Performance and reliability targets met.
2. No P0/P1 defects open.

## 10. Backlog Priority (Top 20)

1. Fix saved view modified-date rule correctness bug.
2. Introduce generated API client scaffold.
3. Add mandatory CI lint/test workflow.
4. Implement local DB document cache.
5. Implement local DB label cache.
6. Add custom field support to upload payload.
7. Add custom field section in document detail/edit.
8. Add custom field filter builder.
9. Add custom field bulk modify UI + API mapping.
10. Refactor task tracking to adaptive polling/batching.
11. Replace mutable state update hotspots with immutable patterns.
12. Unify state management conventions across features.
13. Add document permissions editing UX.
14. Add bulk permission operation UX.
15. Add resumable upload queue with persisted jobs.
16. Add ingestion failure diagnostics and retry actions.
17. Add saved view full-fidelity serialization tests.
18. Remove hardcoded non-localized strings.
19. Add performance instrumentation dashboards.
20. Add end-to-end tests for login/search/upload/task lifecycle.

## 11. Risks and Mitigations

1. Risk: Server API drift across versions.
   - Mitigation: schema-driven client + compatibility adapter + integration matrix.
2. Risk: Rewrite stalls due to broad scope.
   - Mitigation: strict phase gates and feature-flagged slice delivery.
3. Risk: Performance regressions in list/image rendering.
   - Mitigation: early profiling budget and regression benchmarks in CI.
4. Risk: Background behavior differences across Android OEMs.
   - Mitigation: queue persistence + explicit retry UX + constrained background assumptions.

## 12. Definition of Done (Rewrite v1)

1. Phase 0-5 acceptance criteria completed.
2. Quality gates green for release branch.
3. Feature parity baseline achieved for:
   - Core documents flows.
   - Custom fields (view/edit/filter/bulk).
   - Ingestion and task lifecycle.
   - Saved views and permissions workflows.
4. Performance/reliability targets met in beta telemetry.

