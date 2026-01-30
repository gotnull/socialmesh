# Automation Engine Testing Plan

## Overview

This document outlines the comprehensive testing strategy for the Socialmesh Automation Engine, ensuring complete coverage of all TriggerTypes, ActionTypes, and ConditionTypes.

**Total Tests: 172**

- automation_engine_test.dart: 76 tests
- automation_repository_test.dart: 35 tests
- automation_test.dart (models): 59 tests
- presence_detection_test.dart: 2 tests

## Architecture Summary

### Entry Points

- `AutomationEngine.processNodeUpdate()` - Node state changes (battery, position, presence)
- `AutomationEngine.processMessage()` - Message events
- `AutomationEngine.processDetectionSensorEvent()` - Sensor telemetry
- `AutomationEngine.processPresenceUpdate()` - Online/offline transitions
- `AutomationEngine.executeAutomationManually()` - Manual/Shortcut triggers
- `AutomationEngine._checkSilentNodes()` - Timer-based silent node detection

### Key Files

| File                                                  | Purpose             |
| ----------------------------------------------------- | ------------------- |
| `lib/features/automations/automation_engine.dart`     | Core engine logic   |
| `lib/features/automations/models/automation.dart`     | Data models & enums |
| `lib/features/automations/automation_repository.dart` | Persistence layer   |

---

## Test Matrix

### TriggerTypes (16 total) - ✅ ALL IMPLEMENTED TRIGGERS TESTED

| TriggerType       | Status                 | Test Count | Notes                                          |
| ----------------- | ---------------------- | ---------- | ---------------------------------------------- |
| `nodeOnline`      | ✅ Tested              | 4          | Online transitions, node filter, disabled auto |
| `nodeOffline`     | ✅ Tested              | 2          | Offline transitions, node filter               |
| `batteryLow`      | ✅ Tested              | 6          | Threshold crossing, hysteresis, custom         |
| `batteryFull`     | ✅ Tested              | 1          | Full charge detection                          |
| `messageReceived` | ✅ Tested              | 2          | Any message trigger                            |
| `messageContains` | ✅ Tested              | 3          | Keyword matching, case-insensitive             |
| `positionChanged` | ✅ Tested              | 2          | Position update detection                      |
| `geofenceEnter`   | ✅ Tested              | 2          | Enter zone detection                           |
| `geofenceExit`    | ✅ Tested              | 2          | Exit zone detection                            |
| `nodeSilent`      | ✅ Tested              | 3          | Silent threshold, node filter, config duration |
| `scheduled`       | ⚠️ Not Implemented     | 0          | Enum exists but no timer/cron support          |
| `signalWeak`      | ✅ Tested              | 2          | SNR threshold                                  |
| `channelActivity` | ✅ Tested              | 1          | Channel-specific triggers                      |
| `detectionSensor` | ✅ Tested              | 9          | Sensor name/state filters, node filter         |
| `manual`          | ✅ Tested              | 3          | Manual execution, context passing              |

### ActionTypes (10 total) - ✅ ALL TESTED

| ActionType         | Status    | Test Count | Notes                                    |
| ------------------ | --------- | ---------- | ---------------------------------------- |
| `sendMessage`      | ✅ Tested | 5          | Variable interpolation, error handling   |
| `sendToChannel`    | ✅ Tested | 2          | Channel sending                          |
| `playSound`        | ✅ Tested | 2          | Missing config handling, RTTTL calls     |
| `vibrate`          | ✅ Tested | 1          | Haptic feedback                          |
| `pushNotification` | ✅ Tested | 2          | Title/body interpolation                 |
| `triggerWebhook`   | ✅ Tested | 4          | IFTTT integration, error handling        |
| `logEvent`         | ✅ Tested | 1          | Always succeeds (no-op)                  |
| `updateWidget`     | ✅ Tested | 1          | Stub implementation (WidgetKit pending)  |
| `triggerShortcut`  | ✅ Tested | 2          | URL scheme, missing name handling        |
| `glyphPattern`     | ✅ Tested | 2          | Pattern validation, default handling     |

### ConditionTypes (8 total) - ✅ ALL TESTED

| ConditionType     | Status    | Test Count | Notes                          |
| ----------------- | --------- | ---------- | ------------------------------ |
| `timeRange`       | ✅ Tested | 4          | In range, out of range         |
| `dayOfWeek`       | ✅ Tested | 2          | Matching/non-matching days     |
| `batteryAbove`    | ✅ Tested | 2          | Threshold comparison           |
| `batteryBelow`    | ✅ Tested | 2          | Threshold comparison           |
| `nodeOnline`      | ✅ Tested | 2          | Presence-based condition       |
| `nodeOffline`     | ✅ Tested | 2          | Inverse presence condition     |
| `withinGeofence`  | ✅ Tested | 1          | Stub (always true) - documented|
| `outsideGeofence` | ✅ Tested | 1          | Stub (always true) - documented|

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
├── models/
│   └── automation_test.dart         # Model serialization
└── utils/
    ├── fake_services.dart           # Mock services
    ├── test_helpers.dart            # Assertion helpers
    └── fake_clock.dart              # Time control
```

---

## Notes

### Known Limitations

1. **Scheduled Triggers**: `TriggerType.scheduled` enum exists but has no implementation. No cron/timer support beyond silent node monitoring.

2. **Geofence Conditions**: `withinGeofence` and `outsideGeofence` conditions always return `true`. The geofence _triggers_ work, but conditions don't.

3. **Widget Updates**: `ActionType.updateWidget` is a no-op stub awaiting WidgetKit integration.

### Dependencies for Testing

- `flutter_test` - Built-in test framework
- `mocktail` or `mockito` - Mock generation (if needed)
- `fake_async` - Time manipulation

### CI Integration

Add to GitHub Actions workflow:

```yaml
- name: Run Automation Tests
  run: flutter test test/features/automations/ --coverage
```
