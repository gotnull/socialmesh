# Cloud Sync Coverage Map

Last updated: 2025-01-28

This document tracks every user-created or user-curated data domain in Socialmesh
and its Cloud Sync status. Cloud Sync is a paid entitlement (Monthly/Yearly) managed
via RevenueCat. All sync is offline-first with local SQLite/SharedPreferences as
source of truth.

## Architecture Summary

| Component | File Path |
|---|---|
| Entitlement Service | `lib/services/subscription/cloud_sync_entitlement_service.dart` |
| Entitlement Providers | `lib/providers/cloud_sync_entitlement_providers.dart` |
| NodeDex SQLite Store | `lib/features/nodedex/services/nodedex_sqlite_store.dart` |
| NodeDex Database Schema | `lib/features/nodedex/services/nodedex_database.dart` |
| NodeDex Sync Service | `lib/features/nodedex/services/nodedex_sync_service.dart` |
| NodeDex Providers | `lib/features/nodedex/providers/nodedex_providers.dart` |
| NodeDex Entry Model | `lib/features/nodedex/models/nodedex_entry.dart` |
| Profile Cloud Sync | `lib/services/profile/profile_cloud_sync_service.dart` |
| Profile Providers | `lib/providers/profile_providers.dart` |
| User Profile Model | `lib/models/user_profile.dart` |
| Automation Repository | `lib/features/automations/automation_repository.dart` |
| Automation Providers | `lib/features/automations/automation_providers.dart` |
| Signal Service | `lib/services/signal_service.dart` |
| Sync Contract Registry | `lib/services/sync/sync_contract.dart` |
| Sync Diagnostics | `lib/services/sync/sync_diagnostics.dart` |

## Sync Flow

```
Local mutation
  -> SQLite write (immediate or debounced)
  -> Outbox entry enqueued (if Cloud Sync entitlement active)
  -> Periodic drain (every 2 min) OR immediate drain (user mutations)
  -> Firestore upsert to users/{uid}/nodedex_sync/{entityType}_{entityId}
  -> Pull: query Firestore for updated_at_ms > last watermark
  -> Merge: applySyncPull with conflict resolution
  -> UI reload via onPullApplied callback
```

## Coverage Table

### Legend

- **Status**: Fully synced / Partially synced / Not synced / Not applicable
- **Entitlement Gated**: Whether sync requires active Cloud Sync subscription
- **Conflict Policy**: How conflicts between devices are resolved
- **Tombstone**: Whether deletes are propagated across devices

---

### NodeDex Domain

| Entity | Status | Local Storage | Cloud Path | ID Strategy | updatedAt Tracked | Tombstone | Conflict Policy | Entitlement Gated |
|---|---|---|---|---|---|---|---|---|
| NodeDex Entry (core metrics) | Fully synced | SQLite `nodedex_entries` | `users/{uid}/nodedex_sync/entry_node:{nodeNum}` | `node:{nodeNum}` | Yes (`updated_at_ms` in row + JSON) | Yes (soft-delete `deleted=1`) | Metric merge: min firstSeen, max lastSeen, max counts | Yes |
| Encounters | Fully synced | SQLite `nodedex_encounters` | Embedded in entry JSON `enc` array | Deduped by timestamp ms | Via parent entry | Via parent entry | Union by timestamp, keep most recent N | Yes |
| Seen Regions | Fully synced | SQLite `nodedex_seen_regions` | Embedded in entry JSON `sr` array | `regionId` (geohash) | Via parent entry | Via parent entry | Merge by regionId: min firstSeen, max lastSeen, max count | Yes |
| Co-Seen Edges | Fully synced | SQLite `nodedex_coseen_edges` | Embedded in entry JSON `csn` map | `{nodeNumA}_{nodeNumB}` canonical | Via parent entry | Via parent entry | Merge per edge: max count, min firstSeen, max lastSeen | Yes |
| Sigil Data | Fully synced | SQLite `sigil_json` column | Embedded in entry JSON `sig` | Deterministic from nodeNum | Via parent entry | Via parent entry | Prefer local non-null (deterministic, so identical) | Yes |
| Classification (socialTag) | **Fully synced** | SQLite `social_tag` column | Embedded in entry JSON `st` + `st_ms` | Via parent entry | **Yes (`st_ms` field)** | Via parent entry | **Last-write-wins by `st_ms`; conflict copy if within 5s window** | Yes |
| User Note (userNote) | **Fully synced** | SQLite `user_note` column | Embedded in entry JSON `un` + `un_ms` | Via parent entry | **Yes (`un_ms` field)** | Via parent entry | **Last-write-wins by `un_ms`; conflict copy if within 5s window** | Yes |

### Profile Domain

| Entity | Status | Local Storage | Cloud Path | ID Strategy | updatedAt Tracked | Tombstone | Conflict Policy | Entitlement Gated |
|---|---|---|---|---|---|---|---|---|
| User Profile | Fully synced | SharedPreferences via ProfileService | `users/{uid}` + `profiles/{uid}` | Firebase Auth UID | Yes (`updatedAt` server timestamp) | No (profile deleted on account delete) | Local-first with server merge | No (syncs for all signed-in users) |
| Avatar Image | Fully synced | Local file system | Firebase Storage `profile_avatars/{uid}.jpg` | Firebase Auth UID | Via parent profile | Via explicit delete | Upload overwrites | No |
| Banner Image | Fully synced | Local file system | Firebase Storage `profile_banners/{uid}.jpg` | Firebase Auth UID | Via parent profile | Via explicit delete | Upload overwrites | No |
| Display Name | Fully synced | Via profile | Via profile + uniqueness check | Firebase Auth UID | Via parent profile | Via parent profile | Uniqueness enforced server-side | No |

### Settings / Preferences Domain

| Entity | Status | Local Storage | Cloud Path | ID Strategy | updatedAt Tracked | Tombstone | Conflict Policy | Entitlement Gated |
|---|---|---|---|---|---|---|---|---|
| UserPreferences | Fully synced | SharedPreferences via ProfileService | `users/{uid}.preferences` (embedded) | Firebase Auth UID | Via parent profile | Via parent profile | Null-coalescing merge (non-null wins) | No (via profile) |
| Accent Color | Fully synced | SharedPreferences `accent_color` | `users/{uid}.accentColorIndex` | Firebase Auth UID | Via parent profile | Via parent profile | Cloud value applied on login | No (via profile) |
| Theme Mode | Fully synced | Via UserPreferences | Via profile preferences | Firebase Auth UID | Via parent profile | Via parent profile | Via preferences merge | No (via profile) |
| Haptic Settings | Fully synced | Via UserPreferences | Via profile preferences | Firebase Auth UID | Via parent profile | Via parent profile | Via preferences merge | No (via profile) |
| Animation Settings | Fully synced | Via UserPreferences | Via profile preferences | Firebase Auth UID | Via parent profile | Via parent profile | Via preferences merge | No (via profile) |
| Canned Responses | Fully synced | Via UserPreferences JSON | Via profile preferences | Firebase Auth UID | Via parent profile | Via parent profile | Via preferences merge | No (via profile) |
| Ringtone Selection | Fully synced | Via UserPreferences | Via profile preferences | Firebase Auth UID | Via parent profile | Via parent profile | Via preferences merge | No (via profile) |
| Splash Mesh Config | Fully synced | Via UserPreferences | Via profile preferences | Firebase Auth UID | Via parent profile | Via parent profile | Via preferences merge | No (via profile) |

### Automations Domain

| Entity | Status | Local Storage | Cloud Path | ID Strategy | updatedAt Tracked | Tombstone | Conflict Policy | Entitlement Gated |
|---|---|---|---|---|---|---|---|---|
| Automation Rules | Partially synced | SharedPreferences `automations` JSON | `users/{uid}.preferences.automationsJson` (embedded blob) | UUID per automation | `createdAt` per rule | No (full replace) | Full list replace (last writer wins entire list) | No (via profile prefs) |
| Automation Schedules | Not synced | SharedPreferences `automation_schedules` | None | UUID per schedule | No | No | N/A | N/A |
| Automation Log | Not synced | SharedPreferences `automation_log` | None | Sequential | No | No | N/A (ephemeral) | N/A |
| IFTTT Config | Partially synced | SharedPreferences via UserPreferences | `users/{uid}.preferences.iftttConfigJson` | Singleton | Via parent profile | Via parent profile | Via preferences merge | No (via profile prefs) |

### Signals Domain

| Entity | Status | Local Storage | Cloud Path | ID Strategy | updatedAt Tracked | Tombstone | Conflict Policy | Entitlement Gated |
|---|---|---|---|---|---|---|---|---|
| Signal Posts | Fully synced (independent) | SQLite `signals.db` | `posts/{signalId}` | UUID v4 | `createdAt` | Cloud doc delete | Cloud is authority after initial send | No (auth-gated, not subscription-gated) |
| Signal Comments | Fully synced (independent) | SQLite `comments` table | `posts/{signalId}/comments/{commentId}` | UUID v4 | `createdAt` | `isDeleted` flag | Cloud is authority | No (auth-gated) |
| Signal Images | Fully synced (independent) | Local file + Firebase Storage | `signal_images/{signalId}/` | Via signal ID | `imageState` tracking | Via signal delete | Upload overwrites | No (auth-gated) |

### Not Synced (by design)

| Entity | Reason | Local Storage |
|---|---|---|
| Automation Log | Ephemeral debug data, device-specific | SharedPreferences |
| Automation Schedules | Device-specific platform scheduler state (WorkManager/BGTask) | SharedPreferences |
| Node Proximity History | Ephemeral sensor data for image unlock | SQLite `node_proximity` |
| AR Calibration | Device-specific sensor calibration | SharedPreferences |
| BLE Connection State | Ephemeral runtime state | In-memory |
| Platform Scheduler Tasks | Device-specific OS scheduler registration | SharedPreferences |
| Packet Dedupe Store | Ephemeral protocol-level dedup cache | SQLite `packet_dedupe.db` |
| Routes DB | Ephemeral routing data | SQLite `routes.db` |

---

## Gaps Identified and Fixed

### Gap 1: NodeDex Classification (socialTag) not syncing correctly

**Root cause**: `NodeDexEntry.mergeWith()` used `socialTag ?? other.socialTag` which:
1. Always preferred local non-null value (no last-write-wins)
2. Could never propagate a "clear" operation (null never wins over non-null)
3. Had no per-field timestamp to determine which value is newer

**Fix applied**:
- Added `socialTagUpdatedAtMs` (`st_ms`) field to `NodeDexEntry` for per-field timestamping
- Updated `mergeWith()` to use last-write-wins by comparing `st_ms` timestamps
- Added conflict detection: if both devices modified within 5 seconds and values differ,
  the losing value is preserved (caller can detect via conflict copy)
- Updated `toJson()`/`fromJson()` to serialize/deserialize `st_ms`
- Updated `copyWith()` to propagate timestamp on social tag changes
- Updated `_entryToRow()`/`_rowToEntry()` in SQLite store for new column

### Gap 2: NodeDex User Note (userNote) not syncing correctly

**Root cause**: Same as Classification. `userNote ?? other.userNote` in `mergeWith()`.

**Fix applied**:
- Added `userNoteUpdatedAtMs` (`un_ms`) field to `NodeDexEntry`
- Same last-write-wins + conflict detection pattern as socialTag
- Updated all serialization paths

### Gap 3: No per-field timestamps in sync payload

**Root cause**: `NodeDexEntry.toJson()` did not include any `updatedAt` information.
The `updatedAtMs` existed only in the SQLite row, not in the JSON payload sent to
Firestore. This meant the pull side had no way to determine which entry was newer
for user-editable fields.

**Fix applied**:
- Added `socialTagUpdatedAtMs` and `userNoteUpdatedAtMs` to JSON serialization
- These travel with the entry payload to Firestore and back
- The overall entry `updatedAtMs` in the Firestore wrapper document is still used
  for watermark-based pull queries

### Gap 4: Sync Diagnostics missing

**Root cause**: No observability into sync state. Users and developers had no way to
verify sync was working, see queue depth, or diagnose failures.

**Fix applied**:
- Added `SyncDiagnostics` service with structured logging
- Tracks: entitlement state, last sync time, queued items by type, last error per type
- Debug panel entry (dev flag gated, not user-facing in production)

### Gap 5: No sync contract enforcement

**Root cause**: No automated way to verify all syncable entities are registered and
covered. New entities could be added without sync support and nobody would notice.

**Fix applied**:
- Added `SyncContract` registry with `SyncType` enum
- Each type defines: entity name, cloud collection path, serialization
- Automated test verifies all registered types are properly configured

---

## Conflict Resolution Policy

### Metric Fields (encounterCount, maxDistance, bestSnr, bestRssi, messageCount)
- **Policy**: Take the maximum / best value
- **Rationale**: These are monotonically increasing or "best ever" metrics. Taking the max is always correct and produces no data loss.

### Time Fields (firstSeen, lastSeen)
- **Policy**: firstSeen = min, lastSeen = max
- **Rationale**: Broadest possible time window is the most accurate.

### User-Editable Fields (socialTag, userNote)
- **Policy**: Last-write-wins by per-field timestamp
- **Conflict window**: If both devices modified the same field within 5 seconds AND the values differ, the "losing" value is preserved as a conflict indicator rather than silently dropped.
- **Rationale**: User intent matters. The most recent deliberate action should win, but near-simultaneous edits should not silently lose data.

### Collection Fields (encounters, regions, co-seen edges)
- **Policy**: Union merge with deduplication
- **Rationale**: These are append-only or merge-by-key collections. Combining both sides produces the most complete picture.

### Sigil Data
- **Policy**: Prefer local non-null (deterministic)
- **Rationale**: Sigils are deterministically generated from nodeNum. Both devices produce identical sigils, so preference order does not matter.

---

## Testing Coverage

| Test File | What It Covers |
|---|---|
| `test/features/nodedex/nodedex_entry_test.dart` | Serialization round-trip, mergeWith conflict resolution, socialTag/userNote timestamp-based merge |
| `test/features/nodedex/nodedex_sync_coverage_test.dart` | Sync contract verification, merge scenarios, conflict detection, queue behavior, entitlement gating |
| `test/services/subscription/cloud_sync_entitlement_test.dart` | Entitlement state machine, grace period, expiry |
| `test/services/profile/profile_cloud_sync_service_test.dart` | Profile sync to/from cloud |

---

## How to Verify Sync is Working

1. **Check entitlement**: Settings > Account > Cloud Sync shows active subscription
2. **Debug diagnostics** (dev builds only): Enable via `SYNC_DIAGNOSTICS_ENABLED=true` env flag
3. **Manual test**:
   - Device A: Set a classification on a node, write a note
   - Wait 2 minutes (or force sync)
   - Device B: Sign in with same account, observe classification and note appear
4. **Conflict test**:
   - Both devices offline
   - Device A: Set classification to "Contact"
   - Device B: Set classification to "Trusted Node"
   - Both devices go online
   - Result: One device has "Contact", other has "Trusted Node" (last-write-wins),
     no data is silently lost

---

## Adding New Syncable Entities

When adding a new user-created data domain:

1. Register it in `SyncType` enum in `lib/services/sync/sync_contract.dart`
2. Ensure the entity has:
   - Stable unique ID (UUID or deterministic)
   - `updatedAtMs` timestamp field
   - `toJson()` / `fromJson()` serialization
   - Tombstone support for deletes (`deletedAt` or `isDeleted`)
3. Add outbox enqueuing in the local persistence layer
4. Add pull/apply in the sync service
5. Update this coverage map
6. Add tests in `nodedex_sync_coverage_test.dart`
7. Run `flutter test test/features/nodedex/nodedex_sync_coverage_test.dart` to verify