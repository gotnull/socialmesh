# Release Notes — Cloud Sync v2

**Version:** 2.x.0
**Date:** 7 February 2026
**Category:** Cloud Sync Infrastructure

---

## Summary

This release migrates Automations and Custom Widget Schemas to per-document Cloud Sync, matching the proven outbox pattern used by NodeDex. It also ships critical fixes to the NodeDex sync pipeline (per-UID watermarks, drain mutex) that prevent cross-user data leakage and duplicate uploads.

Cloud Sync remains optional. The app is fully functional offline. All sync features require the Complete Pack entitlement.

---

## What Changed

### NodeDex Sync Fixes

- **Per-UID watermark isolation.** The pull watermark is now scoped to the authenticated user's UID. Previously, signing out and signing in as a different user on the same device could cause the second user's pull to skip documents because the watermark was set by the first user's session. The watermark key is now `nodedex_last_pull_ms_<uid>`.

- **Drain mutex.** A boolean guard prevents concurrent outbox drains. Rapid user actions (e.g., classifying three nodes in quick succession) could previously cause overlapping drain cycles that read the same outbox entries and uploaded them twice. The mutex ensures only one drain runs at a time; subsequent requests are no-ops until the current drain completes.

- **Pull-to-re-enqueue loop prevention.** Pulled data is applied with `syncEnabled = false`, so remotely received entries are not re-enqueued to the outbox. This eliminates the infinite push/pull feedback loop that could occur when the same data was continuously bounced between local and remote.

### Automation Cloud Sync (New)

Automations now sync across devices using the same per-document outbox pattern as NodeDex.

- **SQLite backing store.** Automations are persisted in `automations.db` (schema v1) with three tables: `automations`, `sync_outbox`, `sync_state`. The in-memory cache is loaded on init and kept consistent with the database.

- **Outbox pattern.** Local mutations (create, edit, delete) write to SQLite and enqueue an outbox record in a single transaction. The sync service drains the outbox to Firestore every 2 minutes or on demand via `drainOutboxNow()`.

- **Per-document Firestore storage.** Each automation is its own document at `users/{uid}/automations_sync/{docId}`. Conflict resolution is last-write-wins at the item level using `updated_at_ms`.

- **Soft-delete tombstones.** Deleted automations are marked with `deleted: true` in Firestore so other devices can apply the deletion on pull.

- **One-time SharedPreferences migration.** On first launch with the new build, existing automations are bulk-imported from SharedPreferences into SQLite, enqueued for sync, and the SharedPreferences key is cleared. A `automations_migrated_to_sqlite` flag prevents re-migration.

- **Profile-blob fallback import.** If the user's cloud profile contains `automationsJson` (from the legacy blob sync approach) and the SQLite store is empty, those automations are imported as a one-time safety net.

- **Schedule isolation.** Automation schedules and execution logs remain in SharedPreferences because they are device-local (a schedule registered on Device A should not auto-register on Device B). Only the automation definitions sync.

### Widget Schema Cloud Sync (New)

Custom widget schemas now sync across devices using the same per-document outbox pattern.

- **SQLite backing store.** Widget schemas are persisted in `widgets.db` (schema v1) with three tables: `widgets`, `sync_outbox`, `sync_state`.

- **Outbox pattern.** Same architecture as Automations — local mutations enqueue outbox records, the sync service drains to Firestore periodically.

- **Per-document Firestore storage.** Each widget schema is its own document at `users/{uid}/widgets_sync/{docId}`. Conflict resolution is last-write-wins at the item level.

- **One-time SharedPreferences migration.** Existing custom widgets are migrated from SharedPreferences to SQLite on first launch. Marketplace tracking metadata (installed IDs, schema-to-marketplace mappings) remains in SharedPreferences as it is device-local.

- **Provider-injected storage.** The `widgetStorageServiceProvider` replaces all ad-hoc `WidgetStorageService()` instantiations across screens. Screens now obtain an initialized, store-wired service via Riverpod instead of creating and initializing their own instances.

### Sync Probes (New)

Deterministic end-to-end sync validation probes are now available for all three sync domains.

- **NodeDex probe** (existing, unchanged): creates a test node entry, pushes, pulls, verifies round-trip, cleans up.
- **Automation probe** (new): creates a test automation (`sync_probe_automation_00000000`), pushes to Firestore, pulls back, verifies name and description match, cleans up.
- **Widget probe** (new): creates a test widget (`sync_probe_widget_00000000`), pushes to Firestore, pulls back, verifies name and description match, cleans up.

Each probe reports per-stage results (A through I) with detailed logs prefixed `[SYNC] PROBE:` for easy grepping.

The `SyncProbeResult` class has been extracted to `lib/services/sync/sync_probe_result.dart` as a shared type used by all three probes.

### Sync Contract Updates

- `SyncType.automations` registered with entity key `automation`, collection `automations_sync`, outbox-based, tombstone-supported, entitlement-gated.
- `SyncType.widgetSchemas` registered with entity key `widget`, collection `widgets_sync`, outbox-based, tombstone-supported, entitlement-gated.
- Sync contract completeness test (`nodedex_sync_coverage_test.dart`) covers all 7 registered sync types.

### Firestore Security Rules

New subcollection rules added under `users/{userId}`:

- `automations_sync/{docId}` — owner-only read/write with 500KB size validation
- `widgets_sync/{docId}` — owner-only read/write with 500KB size validation

Rules must be deployed before the app release: `firebase deploy --only firestore:rules`

---

## Database Migrations

Two new SQLite databases are created on first launch:

| Database | File | Schema Version | Tables |
|---|---|---|---|
| Automations | `automations.db` | 1 | `automations`, `sync_outbox`, `sync_state` |
| Widgets | `widgets.db` | 1 | `widgets`, `sync_outbox`, `sync_state` |

Both databases include corruption recovery (delete and recreate on open failure) and downgrade handling (drop and recreate tables).

No existing databases are modified. The existing `signals.db`, `packet_dedupe.db`, `routes.db`, and `nodedex.db` are unaffected.

---

## What Does Not Sync

The following remain device-local by design:

- Automation execution logs (device-specific history)
- Automation schedules (registered with the platform scheduler on each device independently)
- Installed marketplace widget IDs and schema-to-marketplace mappings (tracked in SharedPreferences)
- Dashboard widget layout and ordering
- Device connection state and protocol selection

---

## Developer Toggles

| Toggle | Purpose | Default |
|---|---|---|
| `SYNC_DIAGNOSTICS_ENABLED` | Enables verbose sync diagnostics logging (`SyncDiag:` prefix) | `false` |
| `SYNC_DEBUG` | Enables verbose sync operation logging | `false` |

Enable via `--dart-define=SYNC_DIAGNOSTICS_ENABLED=true` during development.

---

## Deployment Steps

1. Deploy Firestore security rules: `firebase deploy --only firestore:rules --project <production>`
2. Submit app build to App Store Connect and Google Play Console
3. Monitor Firestore usage for the first 24 hours (new read/write volume from `automations_sync` and `widgets_sync`)
4. Monitor crash reports for sync-related exceptions
5. Grep device logs for `[SYNC] ERROR` or `PROBE_RESULT ok=false`

---

## Rollback

- Firestore rules are additive and backward-compatible. No rollback needed.
- Previous app builds ignore the new Firestore subcollections (they did not exist).
- SQLite databases persist locally regardless of sync state. No data loss on downgrade.
- Migration flags (`automations_migrated_to_sqlite`, `widgets_migrated_to_sqlite`) prevent re-migration on upgrade/downgrade cycles.
- Emergency option: revoke Cloud Sync entitlement server-side to disable sync for all users.

---

## QA Reference

See `docs/CLOUD_SYNC_QA_CHECKLIST.md` for the complete staging verification checklist with 15 test scenarios covering sync, migration, offline resilience, entitlement gating, and probe validation.