# Cloud Sync Debug Report

Date: 2025-02-07
Status: Root causes identified and fixed
Severity: Critical (complete sync failure)

---

## Executive Summary

Cloud Sync for NodeDex Classifications and Notes was completely non-functional.
Three distinct bugs were identified through end-to-end code tracing. The primary
root cause (BUG 1) is a missing Firestore security rule that silently denied
every read and write to the sync collection. Two additional bugs were found and
fixed during the audit.

---

## Reproduction Steps

1. Sign in on Device A with an active Cloud Sync subscription.
2. Open NodeDex and set a social tag (classification) on any node.
3. Write a user note on the same node.
4. Wait 2+ minutes for the periodic sync cycle to fire.
5. Sign in on Device B with the same account.
6. Open NodeDex on Device B.
7. Observe: the social tag and user note from Device A do NOT appear.

Expected: Device B should show the same tag and note after sync pull.
Actual: Nothing syncs. No error is shown to the user.

---

## Data Flow Trace

```
Local write (setSocialTag/setUserNote)
  → NodeDexNotifier.setSocialTag() / setUserNote()
    → entry.copyWith(socialTag: tag)          # auto-stamps socialTagUpdatedAtMs
    → store.saveEntry(updated)                # puts in _pendingSaves, schedules debounce
    → _triggerImmediateSync()                 # fire-and-forget
      → store.flush()                         # _flushPendingSaves → _upsertEntryInTxn
        → _upsertEntryInTxn(txn, entry)
          → inserts entry row into SQLite
          → if (syncEnabled) _enqueueOutboxInTxn(txn, ...)   # outbox entry created
      → syncService.drainOutboxNow()
        → _drainOutbox(user.uid)
          → reads outbox entries from SQLite
          → for each entry:
              → Firestore.collection('users/{uid}/nodedex_sync').doc(docId).set(...)
                                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                            THIS FAILS WITH PERMISSION_DENIED (BUG 1)
              → catch(e) → markOutboxAttemptFailed(id, e.toString())
              → after 5 failures → removeOutboxEntry(id)   # silently discarded
```

---

## Identified Bugs

### BUG 1 (CRITICAL): Missing Firestore Security Rules — Stage D + F

**Failing stage(s):** D (upload not occurring) and F (download not occurring)

**Root cause:**
The sync service writes to and reads from:
```
users/{userId}/nodedex_sync/{docId}
```

The Firestore security rules file (`firestore.rules`) had rules for the parent
document `users/{userId}` and for specific subcollections (`activities`,
`saved_signals`, `signalSubscriptions`, `entitlements`, `purchases`), but
**no rule existed for `nodedex_sync`**.

In Firestore, subcollection documents require their own explicit `match` rules.
The parent document rule does NOT cascade to subcollections. Without a matching
rule, Firestore's default behavior is to **deny all access**.

**Evidence:**
- `firestore.rules` lines 107-172: existing subcollection rules listed.
  `nodedex_sync` is absent.
- Every `_drainOutbox` call would catch a `[cloud_firestore/permission-denied]`
  exception, increment `attempt_count`, and after 5 attempts silently discard
  the outbox entry.
- Every `_pullUpdates` call would throw `[cloud_firestore/permission-denied]`
  on the query, caught and logged as `Pull error:`.
- Both errors were logged via `AppLogging.nodeDex()` but not surfaced to the
  user, not prefixed with `[SYNC]`, and diagnostics logging was disabled by
  default (`SYNC_DIAGNOSTICS_ENABLED=false`).

**Fix:**
Added Firestore security rule for `nodedex_sync` subcollection:

```
match /users/{userId} {
  // ... existing rules ...

  // NodeDex Cloud Sync subcollection
  match /nodedex_sync/{docId} {
    allow read: if isOwner(userId);
    allow write: if isOwner(userId) && isValidSize();
  }
}
```

**File:** `firestore.rules` (line ~172)

---

### BUG 2 (HIGH): applySyncPull Re-enqueues Pulled Entries — Stage C (sync loop)

**Failing stage(s):** C (queue creates infinite loop)

**Root cause:**
`NodeDexSqliteStore.applySyncPull()` calls `_upsertEntryInTxn()` for each
pulled entry. `_upsertEntryInTxn()` checks `if (syncEnabled)` and enqueues
the entry to the outbox. Since `syncEnabled` is `true` during a pull, every
pulled entry gets re-enqueued.

This creates an infinite push/pull cycle:
1. Device A pushes entry with `updated_at_ms = T1`
2. Device B pulls entry, applies it, re-enqueues to outbox
3. Device B drains outbox, pushes entry with `updated_at_ms = T2 > T1`
4. Device A's next pull sees `updated_at_ms > watermark`, pulls it
5. Device A re-enqueues, pushes with `updated_at_ms = T3 > T2`
6. Repeat forever

The deduplication in `_enqueueOutboxInTxn` prevents outbox pile-up, but each
drain generates a new Firestore write with a new timestamp, triggering the
next pull. This wastes Firestore reads/writes on every 2-minute sync cycle.

**Evidence:**
- `nodedex_sqlite_store.dart` line ~780: `applySyncPull` calls
  `_upsertEntryInTxn(txn, merged)` without disabling `syncEnabled`.
- `_upsertEntryInTxn` line ~393: `if (syncEnabled)` enqueues to outbox.
- Compare with `bulkInsert()` (line ~792) which correctly saves and restores
  `syncEnabled` around its transaction.

**Fix:**
Modified `applySyncPull()` to temporarily disable `syncEnabled` during the
transaction, matching the pattern used by `bulkInsert()`:

```dart
final prevSync = syncEnabled;
syncEnabled = false;
try {
  await _db.transaction((txn) async { ... });
} finally {
  syncEnabled = prevSync;
}
```

**File:** `lib/features/nodedex/services/nodedex_sqlite_store.dart`

**Test evidence:** `nodedex_sync_pipeline_test.dart` —
"pulled entries are NOT re-enqueued to outbox" (asserts outboxCount == 0 after
`applySyncPull` with `syncEnabled = true`). All 28 pipeline tests pass.

---

### BUG 3 (MEDIUM): Cached Entitlement Deserialization — Stage A

**Failing stage(s):** A (entitlement gating blocks sync on restart)

**Root cause:**
`CloudSyncEntitlementService._deserializeEntitlement()` reconstructs a
`CloudSyncEntitlement` from a cached state string. The `canWrite` flag was
computed as:

```dart
canWrite: state == active || state == gracePeriod || state == grandfathered
```

The `cancelled` state was missing. A cancelled-but-still-active subscription
should have `canWrite = true` (the user paid through the current period).
This matches `_resolveEntitlementFromCustomerInfo()` which correctly returns
`canWrite: true` for cancelled subscriptions.

On app restart, the cached entitlement loads first (for instant UI). If the
user's subscription is cancelled but active, the cached value incorrectly
sets `canWrite = false`. The sync service receives `setEnabled(false)` and
does not start. The live refresh from RevenueCat corrects this, but there is
a window where sync is disabled, and if the refresh fails (network error),
sync stays disabled for the session.

**Fix:**
Added `cancelled` to the `canWrite` check in `_deserializeEntitlement`:

```dart
canWrite: state == active || state == cancelled ||
          state == gracePeriod || state == grandfathered,
```

**File:** `lib/services/subscription/cloud_sync_entitlement_service.dart`

---

## Failure Stage Checklist (A-J)

| Stage | Description                          | Status    | Details |
|-------|--------------------------------------|-----------|---------|
| A     | Entitlement gating                   | BUG 3     | `_deserializeEntitlement` missing `cancelled` state |
| B     | Local writes not enqueuing           | OK        | `_upsertEntryInTxn` enqueues when `syncEnabled=true` |
| C     | Queue not flushing / sync loop       | BUG 2     | `applySyncPull` re-enqueues, creating infinite loop |
| D     | Upload not occurring                 | **BUG 1** | Firestore rules deny write to `nodedex_sync` |
| E     | Upload writing wrong path/user scope | OK        | Path is `users/{uid}/nodedex_sync/{docId}`, correct |
| F     | Download not occurring               | **BUG 1** | Firestore rules deny read from `nodedex_sync` |
| G     | Download occurs but apply broken     | OK        | `applySyncPull` merges correctly |
| H     | Conflicts/timestamps block apply     | OK        | Last-write-wins with per-field timestamps works |
| I     | Deletes/tombstones break state       | OK        | Soft-delete with `deleted` flag, skipped in pull |
| J     | Multi-device identity mismatch       | OK        | Both push and pull use `FirebaseAuth.instance.currentUser.uid` |

---

## Code Diff Summary

### Modified Files

1. **`firestore.rules`**
   - Added `nodedex_sync` subcollection rule under `users/{userId}`
   - Owner read + owner write with size validation

2. **`lib/features/nodedex/services/nodedex_sqlite_store.dart`**
   - `applySyncPull()`: wrap transaction in `syncEnabled = false` / restore
   - Prevents pulled entries from being re-enqueued to outbox

3. **`lib/services/subscription/cloud_sync_entitlement_service.dart`**
   - `_deserializeEntitlement()`: added `cancelled` to `canWrite` check

4. **`lib/features/nodedex/services/nodedex_sync_service.dart`**
   - Added `[SYNC]` prefix to ALL log messages for easy grepping
   - Added `SYNC_DEBUG` build-time flag (`--dart-define=SYNC_DEBUG=true`)
   - Added `setSyncDebug(bool)` for runtime toggle
   - Added verbose logging at every boundary: entitlement, uid, collection
     paths, outbox counts, drain results, pull watermarks, apply counts,
     error details with stack traces
   - Added `runSyncProbe()` method for deterministic end-to-end validation
   - Added `SyncProbeResult` class with per-stage results and log capture

### Added Files

5. **`test/features/nodedex/nodedex_sync_pipeline_test.dart`**
   - 28 tests covering: outbox isolation during pull, entitlement states,
     outbox enqueue/dequeue, watermark persistence, serialization round-trips,
     merge semantics during pull

6. **`docs/sync_debug_report.md`**
   - This file

---

## Verification Evidence

### A) Unit Test Results

```
flutter test test/features/nodedex/nodedex_sync_pipeline_test.dart
  28 tests passed, 0 failures (EXIT=0)

flutter test test/features/nodedex/nodedex_sync_coverage_test.dart
  78 tests passed, 0 failures (EXIT=0)
```

Key assertions that prove the fix:

- "pulled entries are NOT re-enqueued to outbox"
  `expect(outboxAfterPull, 0)` — PASSED

- "pulled entries merging with local entries do NOT create outbox entries"
  `expect(outboxAfterPull, 0)` — PASSED

- "local saves AFTER pull still enqueue to outbox"
  `expect(outboxAfterLocalSave, greaterThan(0))` — PASSED

- "syncEnabled is restored after applySyncPull"
  `expect(store.syncEnabled, true)` — PASSED

- "bulk pull of 10 entries creates zero outbox entries"
  `expect(outboxCount, 0)` — PASSED

### B) Sync Probe (runtime validation)

After deploying the Firestore rules update, run the Sync Probe to validate
the full pipeline on a real device:

```dart
final syncService = ref.read(nodeDexSyncServiceProvider);
final result = await syncService?.runSyncProbe();
// Check: result.ok == true
// Grep logs for: [SYNC] PROBE_RESULT ok=true
```

The probe executes stages A through I:
- A: Check entitlement is active
- B: Check Firebase auth user exists
- C: Create test entry in SQLite
- D: Verify outbox has entry
- E: Drain outbox to Firestore
- F: Verify document exists in Firestore
- G: Pull from Firestore
- H: Verify entry exists locally after pull with correct data
- I: Clean up probe data

### C) Debug Mode

Enable verbose sync logging for runtime diagnosis:

Build-time:
```
flutter run --dart-define=SYNC_DEBUG=true
```

Runtime (from debug panel or console):
```dart
import 'package:socialmesh/features/nodedex/services/nodedex_sync_service.dart';
setSyncDebug(true);
```

All sync operations log with `[SYNC]` prefix. Grep with:
```
adb logcat | grep "\[SYNC\]"
```

---

## Deployment Checklist

- [ ] Deploy updated `firestore.rules` to Firebase project
      (`firebase deploy --only firestore:rules`)
- [ ] Verify rules deployed: check Firebase Console > Firestore > Rules
- [ ] Build app with fixes and install on two test devices
- [ ] Run Sync Probe on Device A — verify `PROBE_RESULT ok=true`
- [ ] Set social tag on Device A, wait 2 min, verify on Device B
- [ ] Set user note on Device A, wait 2 min, verify on Device B
- [ ] Clear social tag on Device A, verify cleared on Device B
- [ ] Test with airplane mode: edit offline, reconnect, verify sync
- [ ] Monitor Firestore usage for 24h to confirm no sync loop (BUG 2 fix)

---

## Remaining Considerations

1. **Firestore rules entitlement gating**: The current `nodedex_sync` rule
   uses simple owner-based auth (`isOwner(userId)`). The other sync collections
   (`synced_nodes`, `synced_messages`, etc.) use `hasCloudSyncAccess(userId)`
   which checks the `user_entitlements` collection. Consider adding entitlement
   checking to `nodedex_sync` rules for server-side enforcement. Currently
   entitlement is only checked client-side via RevenueCat.

2. **Error surfacing**: Sync errors are now logged with `[SYNC]` prefix but
   still not shown to the user in the UI. Consider adding a sync status
   indicator or error banner when sync fails repeatedly.

3. **Firestore composite index**: The `_pullUpdates` query uses
   `orderBy('updated_at_ms')` with `where('updated_at_ms', isGreaterThan: ...)`
   on the same field. Firestore auto-creates single-field indexes, so no
   manual index is needed. If the query pattern changes, check
   `firestore.indexes.json`.