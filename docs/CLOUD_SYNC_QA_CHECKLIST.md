# Cloud Sync QA Checklist — Automations and Widget Schemas

Production release verification for per-document outbox sync migration.

Date: 7 February 2026
Applies to: NodeDex fixes, Automation sync, Widget Schema sync

---

## Pre-Deployment

### Firestore Rules

- [ ] Review `firestore.rules` contains `automations_sync` subcollection rules (owner-only read/write, size check)
- [ ] Review `firestore.rules` contains `widgets_sync` subcollection rules (owner-only read/write, size check)
- [ ] Deploy rules to staging project: `firebase deploy --only firestore:rules --project <staging>`
- [ ] Verify rules deploy without errors

### Build

- [ ] Run `flutter analyze` on `lib/` — zero issues (info, warning, error)
- [ ] Run `flutter test test/features/nodedex/nodedex_sync_coverage_test.dart` — all 78 tests pass
- [ ] Run `flutter test test/features/widget_builder/storage/widget_storage_service_test.dart` — all tests pass
- [ ] Build staging IPA/APK with Cloud Sync enabled

---

## Device Setup

Minimum two devices required. Referred to as **Device A** and **Device B** below.

- [ ] Install staging build on Device A (iOS or Android)
- [ ] Install staging build on Device B (different platform preferred)
- [ ] Sign in to the same account on both devices (must have Complete Pack entitlement)
- [ ] Confirm Cloud Sync is enabled on both devices (Settings > Cloud Sync shows active)

---

## Test 1: Automation Sync — Create and Propagate

**Device A:**

1. [ ] Navigate to Automations screen
2. [ ] Create a new automation:
   - Name: `QA Test Automation`
   - Trigger: Manual
   - Action: Push Notification
3. [ ] Confirm automation appears in the list
4. [ ] Wait 2 minutes (or force sync via debug panel if available)

**Device B:**

5. [ ] Navigate to Automations screen
6. [ ] Confirm `QA Test Automation` appears with correct name, trigger type, and action type
7. [ ] Confirm the automation is disabled (default state)

**Result:** [ ] PASS / [ ] FAIL

---

## Test 2: Automation Sync — Edit and LWW

**Device A:**

1. [ ] Edit `QA Test Automation` — change name to `QA Test Automation (Edited)`
2. [ ] Wait for sync cycle

**Device B:**

3. [ ] Confirm the name updated to `QA Test Automation (Edited)`
4. [ ] Confirm trigger and action remain unchanged

**Result:** [ ] PASS / [ ] FAIL

---

## Test 3: Automation Sync — Delete

**Device A:**

1. [ ] Delete `QA Test Automation (Edited)`
2. [ ] Confirm it disappears from the list
3. [ ] Wait for sync cycle

**Device B:**

4. [ ] Confirm the automation disappears from the list
5. [ ] Confirm no ghost entries or duplicates

**Result:** [ ] PASS / [ ] FAIL

---

## Test 4: Automation Sync — Concurrent Edit (LWW Verification)

**Both devices — perform within 30 seconds of each other:**

1. [ ] Create automation `LWW Test` on Device A
2. [ ] Wait for it to appear on Device B
3. [ ] On Device A: change name to `LWW Test — Device A`
4. [ ] On Device B: change name to `LWW Test — Device B` (before A syncs)
5. [ ] Wait for both sync cycles to complete

**Expected:**

6. [ ] Both devices converge to the same name (last writer wins)
7. [ ] No data loss — the automation exists on both devices
8. [ ] No duplicate automations created

**Result:** [ ] PASS / [ ] FAIL

---

## Test 5: Widget Schema Sync — Create and Propagate

**Device A:**

1. [ ] Navigate to Widget Builder (My Widgets)
2. [ ] Create a new custom widget:
   - Name: `QA Test Widget`
   - Add a text element with content `Hello QA`
3. [ ] Save the widget
4. [ ] Wait for sync cycle

**Device B:**

5. [ ] Navigate to Widget Builder
6. [ ] Confirm `QA Test Widget` appears in the list
7. [ ] Open it in the editor — confirm the text element with `Hello QA` exists

**Result:** [ ] PASS / [ ] FAIL

---

## Test 6: Widget Schema Sync — Edit and Propagate

**Device A:**

1. [ ] Edit `QA Test Widget` — change name to `QA Test Widget v2`
2. [ ] Save and wait for sync

**Device B:**

3. [ ] Confirm the widget name updated to `QA Test Widget v2`
4. [ ] Confirm widget content (text element) is preserved

**Result:** [ ] PASS / [ ] FAIL

---

## Test 7: Widget Schema Sync — Delete

**Device A:**

1. [ ] Delete `QA Test Widget v2`
2. [ ] Confirm it disappears

**Device B:**

3. [ ] Wait for sync cycle
4. [ ] Confirm the widget is removed from the list

**Result:** [ ] PASS / [ ] FAIL

---

## Test 8: Marketplace Widget Install Sync

**Device A:**

1. [ ] Install a widget from the Marketplace
2. [ ] Confirm it appears in My Widgets with the marketplace badge
3. [ ] Wait for sync cycle

**Device B:**

4. [ ] Confirm the installed widget appears (or is restored from marketplace)
5. [ ] Confirm installed marketplace IDs are tracked correctly in the profile

**Result:** [ ] PASS / [ ] FAIL

---

## Test 9: Migration from SharedPreferences (First Run)

**Preparation:**

1. [ ] Install a previous build (pre-SQLite migration) on a test device
2. [ ] Create 2 automations and 1 custom widget using the old build
3. [ ] Upgrade to the new staging build (do not clear app data)

**Verification:**

4. [ ] Launch the app — confirm no crash during startup
5. [ ] Navigate to Automations — confirm both automations are present
6. [ ] Navigate to Widget Builder — confirm the custom widget is present
7. [ ] Check logs for `Migration to SQLite complete` messages (both automation and widget stores)
8. [ ] Wait for sync cycle — confirm data reaches Firestore
9. [ ] Sign in on Device B — confirm migrated data appears

**Result:** [ ] PASS / [ ] FAIL

---

## Test 10: Profile-Blob Fallback Import (Cloud Prefs)

This tests the safety net for users who synced automations via the old profile blob.

1. [ ] On a fresh install, sign in to an account that has `automationsJson` in the profile document
2. [ ] Confirm automations are imported from the profile blob into SQLite
3. [ ] Confirm the imported automations are enqueued for sync
4. [ ] Confirm `importFromCloudPrefsIfEmpty` only runs when the SQLite store is empty

**Result:** [ ] PASS / [ ] FAIL (or N/A if no profile-blob users exist)

---

## Test 11: NodeDex Sync Fixes Verification

**Per-UID Watermark:**

1. [ ] Sign in as User X on Device A — sync some NodeDex data
2. [ ] Sign out, sign in as User Y on Device A
3. [ ] Confirm User Y does not see User X's NodeDex data
4. [ ] Confirm watermark is per-UID (check `sync_state` table if possible)

**Drain Mutex:**

5. [ ] Trigger rapid saves (classify 3 nodes in quick succession)
6. [ ] Check logs — confirm no `drain already in progress` overlap warnings indicating data corruption
7. [ ] Confirm all 3 classifications reach Firestore

**Result:** [ ] PASS / [ ] FAIL

---

## Test 12: Sync Probe Verification

Run the built-in sync probes to validate the full pipeline.

**NodeDex Probe:**

1. [ ] Trigger NodeDex sync probe (via debug panel or programmatically)
2. [ ] Confirm all stages A through I pass
3. [ ] Confirm probe data is cleaned up after completion

**Automations Probe:**

4. [ ] Trigger Automation sync probe
5. [ ] Confirm all stages A through I pass
6. [ ] Confirm no residual `sync_probe_automation_00000000` entry in local store or Firestore

**Widgets Probe:**

7. [ ] Trigger Widget sync probe
8. [ ] Confirm all stages A through I pass
9. [ ] Confirm no residual `sync_probe_widget_00000000` entry in local store or Firestore

**Result:** [ ] PASS / [ ] FAIL

---

## Test 13: Offline Resilience

1. [ ] Enable airplane mode on Device A
2. [ ] Create an automation and a custom widget
3. [ ] Confirm both are saved locally (visible in their respective screens)
4. [ ] Disable airplane mode
5. [ ] Wait for sync cycle
6. [ ] Confirm data appears on Device B

**Result:** [ ] PASS / [ ] FAIL

---

## Test 14: Entitlement Gating

1. [ ] Sign in with an account that does NOT have Complete Pack
2. [ ] Confirm Cloud Sync is disabled (sync engine logs `STOPPED`)
3. [ ] Create an automation — confirm it saves locally but does NOT enqueue to outbox
4. [ ] Upgrade to Complete Pack
5. [ ] Confirm sync enables and existing data is pushed

**Result:** [ ] PASS / [ ] FAIL

---

## Test 15: Schedule and Trigger Registration

After migration, automation schedules and triggers must still function correctly.

1. [ ] Create a scheduled automation (e.g., daily at a specific time)
2. [ ] Confirm the schedule is registered with the platform scheduler
3. [ ] Edit the automation — confirm the schedule updates
4. [ ] Delete the automation — confirm the schedule is unregistered
5. [ ] After sync pull on Device B — confirm schedules are NOT duplicated (schedules are device-local)

**Result:** [ ] PASS / [ ] FAIL

---

## Log Verification

After completing all tests, check device logs for anomalies:

- [ ] `adb logcat | grep "\[SYNC\]"` (Android) — no repeated FAIL entries
- [ ] No `pull -> re-enqueue` loop indicators (outbox count should not grow unboundedly)
- [ ] Watermark values advance monotonically per UID
- [ ] No `PROBE_RESULT ok=false` entries
- [ ] `SyncDiag` entries show expected upload/pull counts

---

## Firestore Verification

After completing all tests, check the Firestore console:

- [ ] `users/{uid}/automations_sync/` contains expected documents
- [ ] `users/{uid}/widgets_sync/` contains expected documents
- [ ] Each document has `data`, `deleted`, `updated_at_ms`, `entity_type`, `entity_id` fields
- [ ] Deleted items have `deleted: true`
- [ ] No orphaned probe documents remain

---

## Production Deployment

After all tests pass in staging:

1. [ ] Deploy Firestore rules to production: `firebase deploy --only firestore:rules --project <production>`
2. [ ] Submit app build to App Store Connect and Google Play Console
3. [ ] Monitor Firestore usage dashboard for first 24 hours after rollout
4. [ ] Monitor crash reporting for sync-related exceptions
5. [ ] Spot-check `[SYNC]` logs from early adopters (with permission)

---

## Sign-Off

| Role | Name | Date | Result |
|------|------|------|--------|
| QA Engineer | | | |
| Developer | | | |
| Product Owner | | | |

---

## Rollback Plan

If critical issues are discovered post-deployment:

1. Firestore rules are backward-compatible — no rollback needed for rules
2. App rollback: the previous build ignores `automations_sync` and `widgets_sync` collections (they did not exist)
3. Data is safe: SQLite databases persist locally regardless of sync state
4. SharedPreferences migration flag (`automations_migrated_to_sqlite`, `widgets_migrated_to_sqlite`) prevents re-migration on downgrade/upgrade cycles
5. If needed: disable Cloud Sync server-side by revoking entitlement flags