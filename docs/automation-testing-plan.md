# Automation Engine Testing Plan

## Overview

This document outlines the comprehensive testing strategy for the Socialmesh Automation Engine, ensuring complete coverage of all TriggerTypes, ActionTypes, and ConditionTypes.

**Total Tests: 207+**

- automation_engine_test.dart: 76 tests
- automation_repository_test.dart: 35 tests
- automation_test.dart (models): 59 tests
- presence_detection_test.dart: 2 tests
- scheduled_trigger_test.dart: 35+ tests

## Architecture Summary

### Entry Points

- `AutomationEngine.processNodeUpdate()` - Node state changes (battery, position, presence)
- `AutomationEngine.processMessage()` - Message events
- `AutomationEngine.processDetectionSensorEvent()` - Sensor telemetry
- `AutomationEngine.processPresenceUpdate()` - Online/offline transitions
- `AutomationEngine.executeAutomationManually()` - Manual/Shortcut triggers
- `AutomationEngine.processScheduledEvent()` - Scheduled trigger fires
- `AutomationEngine._checkSilentNodes()` - Timer-based silent node detection

### Key Files

| File                                                  | Purpose                      |
| ----------------------------------------------------- | ---------------------------- |
| `lib/features/automations/automation_engine.dart`     | Core engine logic            |
| `lib/features/automations/models/automation.dart`     | Data models & enums          |
| `lib/features/automations/models/schedule_spec.dart`  | Scheduled trigger data model |
| `lib/features/automations/scheduler_service.dart`     | In-app scheduler service     |
| `lib/features/automations/platform_scheduler.dart`    | Platform scheduler stubs     |
| `lib/features/automations/automation_repository.dart` | Persistence layer            |

---

## Test Matrix

### TriggerTypes (16 total) - ✅ ALL IMPLEMENTED TRIGGERS TESTED

| TriggerType       | Status    | Test Count | Notes                                            |
| ----------------- | --------- | ---------- | ------------------------------------------------ |
| `nodeOnline`      | ✅ Tested | 4          | Online transitions, node filter, disabled auto   |
| `nodeOffline`     | ✅ Tested | 2          | Offline transitions, node filter                 |
| `batteryLow`      | ✅ Tested | 6          | Threshold crossing, hysteresis, custom           |
| `batteryFull`     | ✅ Tested | 1          | Full charge detection                            |
| `messageReceived` | ✅ Tested | 2          | Any message trigger                              |
| `messageContains` | ✅ Tested | 3          | Keyword matching, case-insensitive               |
| `positionChanged` | ✅ Tested | 2          | Position update detection                        |
| `geofenceEnter`   | ✅ Tested | 2          | Enter zone detection                             |
| `geofenceExit`    | ✅ Tested | 2          | Exit zone detection                              |
| `nodeSilent`      | ✅ Tested | 3          | Silent threshold, node filter, config duration   |
| `scheduled`       | ✅ Tested | 35+        | One-shot, interval, daily, weekly, DST, catch-up |
| `signalWeak`      | ✅ Tested | 2          | SNR threshold                                    |
| `channelActivity` | ✅ Tested | 1          | Channel-specific triggers                        |
| `detectionSensor` | ✅ Tested | 9          | Sensor name/state filters, node filter           |
| `manual`          | ✅ Tested | 3          | Manual execution, context passing                |

### ActionTypes (10 total) - ✅ ALL TESTED

| ActionType         | Status    | Test Count | Notes                                   |
| ------------------ | --------- | ---------- | --------------------------------------- |
| `sendMessage`      | ✅ Tested | 5          | Variable interpolation, error handling  |
| `sendToChannel`    | ✅ Tested | 2          | Channel sending                         |
| `playSound`        | ✅ Tested | 2          | Missing config handling, RTTTL calls    |
| `vibrate`          | ✅ Tested | 1          | Haptic feedback                         |
| `pushNotification` | ✅ Tested | 2          | Title/body interpolation                |
| `triggerWebhook`   | ✅ Tested | 4          | IFTTT integration, error handling       |
| `logEvent`         | ✅ Tested | 1          | Always succeeds (no-op)                 |
| `updateWidget`     | ✅ Tested | 1          | Stub implementation (WidgetKit pending) |
| `triggerShortcut`  | ✅ Tested | 2          | URL scheme, missing name handling       |
| `glyphPattern`     | ✅ Tested | 2          | Pattern validation, default handling    |

### ConditionTypes (8 total) - ✅ ALL TESTED

| ConditionType     | Status    | Test Count | Notes                           |
| ----------------- | --------- | ---------- | ------------------------------- |
| `timeRange`       | ✅ Tested | 4          | In range, out of range          |
| `dayOfWeek`       | ✅ Tested | 2          | Matching/non-matching days      |
| `batteryAbove`    | ✅ Tested | 2          | Threshold comparison            |
| `batteryBelow`    | ✅ Tested | 2          | Threshold comparison            |
| `nodeOnline`      | ✅ Tested | 2          | Presence-based condition        |
| `nodeOffline`     | ✅ Tested | 2          | Inverse presence condition      |
| `withinGeofence`  | ✅ Tested | 1          | Stub (always true) - documented |
| `outsideGeofence` | ✅ Tested | 1          | Stub (always true) - documented |

---

## Test Strategy

### 1. Unit Tests (Fast, Isolated)

#### A. TriggerType Tests

- Each trigger fires under correct conditions only
- Node/channel/sensor filters work correctly
- Threshold comparisons (battery, signal, silent duration)
- Hysteresis behavior (battery low doesn't re-fire until recovery)

#### B. ActionType Tests

- Each action produces correct side effect
- Error handling for missing configuration
- Variable interpolation in messages/notifications
- Platform-specific actions (iOS shortcuts, Nothing Phone glyphs)

#### C. ConditionType Tests

- Truth tables for each condition
- Boundary values (time range edges, battery thresholds)
- Geofence distance calculations

### 2. Integration Tests (Composition)

- Multi-condition automations (AND logic)
- Multi-action automations (sequential execution)
- Event → Trigger → Condition → Action flow
- Throttling across rapid event bursts

### 3. Edge Cases

- Malformed payloads / missing data
- Network errors (webhook failures)
- Permission denied scenarios
- Timezone handling (DST transitions)
- Concurrent events
- Idempotency (replay same event)

---

## Test Harness Components

### FakeServices (test/utils/automation/)

```dart
/// Fake RTTTL player for sound action testing
class FakeRtttlPlayer {
  final List<String> playedSounds = [];
  bool shouldFail = false;
}

/// Fake URL launcher for shortcut testing
class FakeUrlLauncher {
  final List<Uri> launchedUrls = [];
  bool shouldFail = false;
}

/// Fake GlyphService for Nothing Phone testing
class FakeGlyphService {
  final List<String> shownPatterns = [];
  bool isSupported = true;
}

/// Fake clock for time-based testing
class FakeClock {
  DateTime _now;
  FakeClock([DateTime? initial]) : _now = initial ?? DateTime.now();
  DateTime get now => _now;
  void advance(Duration duration) => _now = _now.add(duration);
}
```

### Assertion Helpers

```dart
void assertActionsExecutedInOrder(List<String> expected, List<String> actual);
void assertNoSideEffects(FakeServices services);
void assertExactlyOnce(List<dynamic> calls, dynamic expected);
void assertCooldownRespected(DateTime first, DateTime second, Duration cooldown);
```

---

## Implementation Checklist

### Phase 1: Missing TriggerTypes ✅ COMPLETE

- [x] `nodeSilent` trigger tests
  - [x] Basic: Silent node triggers after threshold
  - [x] Node filter: Only specific node triggers
  - [x] Configurable duration threshold

- [x] `manual` trigger tests
  - [x] Basic: executeAutomationManually() works
  - [x] Event payload passed correctly
  - [x] Conditions still evaluated

### Phase 2: Missing ActionTypes ✅ COMPLETE

- [x] `playSound` action tests
  - [x] Plays RTTTL sound via callback
  - [x] Handles missing sound config gracefully

- [x] `logEvent` action tests
  - [x] Returns success (always succeeds)

- [x] `updateWidget` action tests
  - [x] Returns success (stub implementation)

- [x] `triggerShortcut` action tests
  - [x] Builds correct URL scheme
  - [x] Handles missing shortcut name

- [x] `glyphPattern` action tests
  - [x] All pattern types work
  - [x] Uses default pattern on error

### Phase 3: Missing ConditionTypes ✅ COMPLETE

- [x] `nodeOffline` condition tests
  - [x] Blocks when node is active
  - [x] Passes when node is inactive

- [x] `withinGeofence` condition tests
  - [x] Documents stub behavior (always true)

- [x] `outsideGeofence` condition tests
  - [x] Documents stub behavior (always true)

### Phase 4: Edge Cases & Integration ✅ COMPLETE

- [x] Throttling tests
  - [x] 1-minute cooldown enforced
  - [x] Different automation IDs throttled independently

- [x] Multi-action execution
  - [x] Sequential execution verified
  - [x] All actions execute even if one fails

- [x] Multi-condition tests
  - [x] AND logic (all conditions must pass)
  - [x] Mixed passing/failing conditions

- [x] Error handling
  - [x] Missing callback (sendMessage = null)
  - [x] Network failure (webhook)
  - [x] IFTTT not configured gracefully handled

- [x] Idempotency tests
  - [x] Same event processed twice respects cooldown

- [x] Event burst handling
  - [x] Multiple events process correctly

---

## How to Run Tests

### Run All Automation Tests

```bash
flutter test test/features/automations/
```

### Run Specific Test File

```bash
flutter test test/features/automations/automation_engine_test.dart
```

### Run With Coverage

```bash
flutter test --coverage test/features/automations/
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Run Specific Test Group

```bash
flutter test test/features/automations/automation_engine_test.dart --name "nodeSilent"
```

---

## Coverage Targets

| Module                     | Target | Current |
| -------------------------- | ------ | ------- |
| automation_engine.dart     | ≥90%   | TBD     |
| automation.dart (models)   | ≥95%   | TBD     |
| automation_repository.dart | ≥85%   | TBD     |

---

## Test File Organization

```
test/features/automations/
├── automation_engine_test.dart      # Core engine tests
├── automation_repository_test.dart  # Persistence tests
├── presence_detection_test.dart     # Presence calculation
├── scheduled_trigger_test.dart      # Scheduled trigger tests (deterministic)
├── models/
│   └── automation_test.dart         # Model serialization
└── utils/
    ├── fake_services.dart           # Mock services
    ├── test_helpers.dart            # Assertion helpers
    └── fake_clock.dart              # Time control
```

---

## Notes

### Scheduled Triggers

The `TriggerType.scheduled` is now fully implemented with comprehensive support for time-based automations.

#### Schedule Kinds

| Kind       | Description                                  | Example                     |
| ---------- | -------------------------------------------- | --------------------------- |
| `oneShot`  | Fires exactly once at a specific time        | "Remind me at 3pm tomorrow" |
| `interval` | Fires repeatedly at fixed intervals          | "Every 15 minutes"          |
| `daily`    | Fires once per day at a specific time        | "Every day at 9:00 AM"      |
| `weekly`   | Fires on specific days of the week at a time | "Mon, Wed, Fri at 8:00 AM"  |

#### DST (Daylight Saving Time) Handling

Scheduled triggers use **Australia/Melbourne** as the default timezone (IANA identifier). The implementation correctly handles DST transitions:

- **Spring Forward**: When clocks advance (e.g., 2:00 AM → 3:00 AM), schedules targeting the skipped hour fire at the wall-clock equivalent (3:00 AM).
- **Fall Back**: When clocks repeat (e.g., 2:00 AM occurs twice), schedules use slot keys that include the UTC offset to deduplicate correctly.

**Slot Key Format**: `{kind}:{isoTimestamp}` where timestamp includes timezone offset (e.g., `daily:2026-01-30T09:00+11:00`)

#### Catch-Up Policies

When the app resumes after being suspended (or after a device reboot), missed scheduled fires are handled according to the configured `CatchUpPolicy`:

| Policy            | Behavior                                            | Use Case                   |
| ----------------- | --------------------------------------------------- | -------------------------- |
| `none`            | Silently discard all missed fires                   | Non-critical notifications |
| `lastOnly`        | Execute only the most recent missed fire            | Status updates             |
| `allWithinWindow` | Execute all missed fires within the catch-up window | Time-critical actions      |

**Safety Limits**:

- `maxCatchUpExecutions`: Hard cap on catch-up fires (default: 10)
- `catchUpWindowDuration`: Maximum lookback window (default: 1 hour)

#### Jitter Support

To prevent thundering herd problems when many automations fire at the same time, schedules support optional jitter:

```dart
ScheduleSpec.interval(
  automationId: 'check-battery',
  interval: Duration(minutes: 15),
  maxJitterMs: 5000, // Random 0-5 second delay
)
```

Jitter is deterministic in tests using seeded `Random` and `FakeClock`.

#### Integration with Conditions

Scheduled triggers integrate with existing conditions (`timeRange`, `dayOfWeek`) using the `evaluationTime` concept:

- For scheduled triggers: conditions evaluate against `scheduledFor` (the intended fire time)
- For other triggers: conditions evaluate against `timestamp` (when the event occurred)

This ensures that a daily schedule set for 9:00 AM correctly passes a "9:00-10:00 AM" time range condition, even if the actual execution is slightly delayed.

#### Persistence

Schedules are persisted via `AutomationRepository`:

- `_schedulesKey`: JSON list of all active schedules
- Each schedule tracks `firedSlots` (Set of slot keys already executed)
- On app restart, `InAppScheduler.resyncFromStore()` rebuilds the priority queue

#### Platform Schedulers

Platform-specific background execution is now fully implemented:

- **Android**: `AndroidWorkManagerScheduler` (WorkManager integration)
- **iOS**: `IOSBGTaskScheduler` (background_fetch + local notifications)

These enable schedules to fire even when the app is suspended. See "Scheduled Triggers in Background" section below for details.

---

### Known Limitations

1. **Geofence Conditions**: `withinGeofence` and `outsideGeofence` conditions always return `true`. The geofence _triggers_ work, but conditions don't.

2. **Widget Updates**: `ActionType.updateWidget` is a no-op stub awaiting WidgetKit integration.

3. **Platform Scheduler Timing**: Both Android WorkManager and iOS background_fetch provide best-effort timing. Exact execution times are not guaranteed due to OS battery optimization.

### Dependencies for Testing

- `flutter_test` - Built-in test framework
- `mocktail` or `mockito` - Mock generation (if needed)
- `fake_async` - Time manipulation (deterministic scheduled trigger tests)

### CI Integration

Add to GitHub Actions workflow:

```yaml
- name: Run Automation Tests
  run: flutter test test/features/automations/ --coverage
```

---

## Scheduled Triggers in Background

### Overview

Scheduled automations can now fire when the app is in the background or terminated, using platform-specific schedulers:

- **Android**: WorkManager for reliable background work
- **iOS**: background_fetch for periodic wake-ups, plus local notifications for exact-time UX

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        SchedulerBridge                          │
│  (Coordinates in-app scheduler with platform schedulers)        │
└─────────────┬───────────────────────────────────┬───────────────┘
              │                                   │
              ▼                                   ▼
┌─────────────────────────┐       ┌──────────────────────────────┐
│     InAppScheduler      │       │     PlatformScheduler        │
│  (Single source of      │       │  (Wakes app in background)   │
│   truth for timing)     │       │                              │
└─────────────────────────┘       └──────────────────────────────┘
                                              │
                          ┌───────────────────┴───────────────────┐
                          ▼                                       ▼
                ┌─────────────────────┐               ┌───────────────────────┐
                │ AndroidWorkManager  │               │   IOSBGTaskScheduler  │
                │   Scheduler         │               │ (background_fetch)    │
                └─────────────────────┘               └───────────────────────┘
```

### Key Design Principles

1. **InAppScheduler is authoritative**: The in-app scheduler owns all timing calculations, catch-up policies, and deduplication logic. Platform schedulers only exist to wake the app.

2. **No duplicate logic**: Platform schedulers don't compute next fire times or handle catch-up. They simply call `InAppScheduler.tick()` when they wake.

3. **Stable task IDs**: Platform task IDs match schedule IDs for easy tracking and cancellation.

4. **Persistent tracking**: Both platforms lack reliable APIs to query "is this task scheduled?", so we track scheduled task IDs in SharedPreferences.

### Android (WorkManager)

**Package**: `workmanager: ^0.5.2`

**How it works**:
- One-shot schedules → `registerOneOffTask` with computed delay
- Interval schedules → `registerPeriodicTask` (minimum 15 minutes)
- Daily/weekly schedules → `registerOneOffTask` for next occurrence, re-registered after firing

**Constraints**:
- Minimum periodic interval: 15 minutes (enforced by Android)
- Exact timing not guaranteed (battery optimization, Doze mode)
- Tasks may be deferred by system

**Callback dispatcher**:
```dart
@pragma('vm:entry-point')
void workManagerCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // Delegates to SchedulerBridge._handlePlatformTask
    // which calls InAppScheduler.tick()
    return true;
  });
}
```

### iOS (background_fetch + Local Notifications)

**Package**: `background_fetch: ^1.3.7`

**How it works**:
- background_fetch provides periodic wake-ups (system-determined, ~15 min minimum)
- On each wake, all due schedules are processed via `InAppScheduler.tick()`
- For exact-time UX, local notifications alert the user (but don't execute code)

**Constraints**:
- iOS determines when to wake the app (not configurable per-task)
- Limited execution time (~30 seconds)
- System may skip wakes based on app usage patterns
- Headless execution available but with restrictions

**One-shot strategy**:
- Store target fire times in SharedPreferences
- Check on each background fetch if any are due
- Optionally schedule a local notification for UX

**Configuration required** (Info.plist):
```xml
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>processing</string>
</array>
```

### Lifecycle Wiring

When app **goes to background**:
```dart
SchedulerBridge.syncToPlatform()
// Cancels all existing platform tasks
// Re-registers all active schedules
```

When app **returns to foreground**:
```dart
SchedulerBridge.processOnResume()
// Calls InAppScheduler.tick() to process any missed schedules
```

### Testing Strategy

**Unit tests** (`scheduler_bridge_test.dart`):
- `MockPlatformScheduler` tracks all calls without platform dependencies
- Tests verify correct registration, cancellation, and sync behavior
- Integration tests simulate platform callbacks

**Manual testing**:
1. Create daily schedule for time in ~2 minutes
2. Background app, wait for schedule time
3. Verify notification (iOS) or app wake (Android)
4. Return to foreground, verify schedule fired

### Platform Limitations Summary

| Feature | Android | iOS |
|---------|---------|-----|
| Minimum periodic interval | 15 minutes | ~15 minutes (system-determined) |
| Exact timing | No (best effort) | No (use local notifications for UX) |
| Task query API | No (tracked manually) | No (tracked manually) |
| Execution time limit | 10 minutes | ~30 seconds |
| Headless execution | Yes | Limited |
| Cold start callback | Yes | Yes |

### How to Enable

**Android** (`android/app/build.gradle.kts`):
No additional configuration needed. WorkManager is automatically initialized.

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>processing</string>
</array>
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
  <string>com.socialmesh.scheduled_automation</string>
</array>
```

**iOS** (`ios/Runner/AppDelegate.swift`):
The background_fetch package handles registration automatically.
