# Rewrite Execution Plan (Implementable, Test-First)

Date: February 16, 2026  
Branch: `rewrite-spec-modern-client`

This plan converts `REWRITE_SPEC.md` into an executable bootstrap cycle that can be completed and verified in this branch.

## Scope of This Execution Cycle

This cycle implements foundational rewrite prerequisites and high-impact correctness/parity items that are currently blocking safe phase execution.

Covered now:

1. Quality guardrails for continuous validation.
2. Critical regression fixes identified in assessment.
3. API parity bootstrap for custom-field upload support.
4. Completion audit with explicit pass/fail criteria.

Deferred to later execution cycles:

1. Full UI/UX rewrite.
2. Full local-first data architecture migration.
3. End-to-end phase rollout from `REWRITE_SPEC.md` Phase 1-5.

## Phase Plan

## Phase 1: Quality Guardrails

Goal:

- Add CI-level validation that runs independently from release pipelines.

Tasks:

1. Add workflow to run static analysis and tests on pull requests and manual dispatch.
2. Ensure both app tests and `paperless_api` package tests are included.

Completion criteria:

1. Workflow exists and is syntactically valid.
2. Workflow runs lint/analyze and test commands for both app and package.

Tests required:

1. Workflow-level: command coverage check by file inspection.

## Phase 2: Critical Correctness Fixes

Goal:

- Eliminate known high-risk logic bugs and mutable-state regressions.

Tasks:

1. Fix saved-view filter parsing bug where `modifiedAfterRule` incorrectly writes to `added`.
2. Remove in-place mutable map update in `PendingTasksNotifier` done/error/ack paths.
3. Remove in-place mutable list update in paged document removal path.
4. Add unit tests to lock behavior.

Completion criteria:

1. Saved view parsing test fails before fix and passes after fix.
2. Notifier tests assert state updates remain immutable and correct.
3. No existing tests regress.

Tests required:

1. `packages/paperless_api/test/parsing/saved_view_test.dart` add regression test for modified-after.
2. New test for notifier map lifecycle and immutability.
3. New test for paged document remove behavior without in-place mutation.

## Phase 3: API Parity Bootstrap (Custom Fields Upload)

Goal:

- Add missing API support for passing custom fields on document upload.

Tasks:

1. Extend document upload API interface and implementation to accept custom fields.
2. Include `custom_fields` payload in multipart upload fields when provided.
3. Propagate API parameter through upload service and upload cubit.
4. Add API serialization tests to prevent regressions.

Completion criteria:

1. `custom_fields` is included in upload request payload when provided.
2. Existing upload tests remain green.
3. New tests cover map and list custom-field forms.

Tests required:

1. Extend `packages/paperless_api/test/api/documents/upload_progress_test.dart` (or add sibling test) to assert `custom_fields` behavior.
2. Add app-level upload service/cubit test for custom-fields pass-through.

## Phase 4: Completion Audit and Iteration Loop

Goal:

- Verify 100% completion of this cycle plan.

Tasks:

1. Run targeted tests for all touched areas.
2. Run a broader sanity check (`flutter analyze`, selected test suites).
3. Record audit table with explicit done/not-done status.
4. If any item fails, fix and rerun until all pass.

Completion criteria:

1. Every checklist item in Phases 1-3 marked complete.
2. All targeted tests pass.
3. Audit document has no open incomplete items.

## Regression Test Matrix

| Area | Risk | Test Type | Test File |
|---|---|---|---|
| Saved view parsing | Wrong date filter field used | Unit | `packages/paperless_api/test/parsing/saved_view_test.dart` |
| Task notifier lifecycle | Hidden mutable state regression | Unit | `test/features/tasks/pending_tasks_notifier_test.dart` |
| Paged remove logic | In-place list mutation side effects | Unit | `test/features/paged_document_view/document_paging_bloc_mixin_test.dart` |
| Upload payload serialization | Missing custom-field API parity | Unit | `packages/paperless_api/test/api/documents/upload_progress_test.dart` |
| Upload passthrough | Parameter lost between layers | Unit | `test/features/document_upload/document_upload_cubit_test.dart` |
| CI safety | Regressions bypass release workflow | Workflow | `.github/workflows/quality.yml` |

## Execution Order

1. Phase 1
2. Phase 2
3. Phase 3
4. Phase 4

No phase is considered complete without tests and explicit verification.

## Completion Audit (Executed February 16, 2026)

### Phase Status

| Phase | Status | Verification |
|---|---|---|
| Phase 1: Quality Guardrails | Complete | `.github/workflows/quality.yml` added with app + `paperless_api` analyze/tests |
| Phase 2: Critical Correctness Fixes | Complete | Code + regression tests added for saved-view parsing, pending-task immutability, paged-list immutability |
| Phase 3: API Parity Bootstrap | Complete | Upload API/service/cubit now supports `custom_fields` via `UploadCustomFields` (ids + value-map forms) |
| Phase 4: Completion Audit Loop | Complete | Failures fixed and checks rerun until green |

### Verification Commands and Results

1. `./flutter-sdk/bin/flutter test test/features/tasks/pending_tasks_notifier_test.dart test/features/paged_document_view/document_paging_bloc_mixin_test.dart test/features/document_upload/document_upload_cubit_test.dart`
   Result: pass
2. `./flutter-sdk/bin/flutter test test/features/document_upload/document_upload_preparation_page_test.dart`
   Result: pass
3. `../../flutter-sdk/bin/flutter test test/parsing/saved_view_test.dart test/api/documents/upload_progress_test.dart` (from `packages/paperless_api`)
   Result: pass
4. `./flutter-sdk/bin/flutter analyze lib test`
   Result: pass
5. `../../flutter-sdk/bin/flutter analyze lib test` (from `packages/paperless_api`)
   Result: pass

### Iteration Notes

1. Initial Phase 3 test run failed on custom-field payload encoding (const factory and map JSON encoding issues).
2. Fixed by:
   - Switching `UploadCustomFields` factories to non-const.
   - Returning JSON-safe values from `UploadCustomFieldValues.toJson()` (stringified keys).
3. Re-ran all targeted and scoped sanity checks to green.
