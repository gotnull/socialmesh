import 'package:flutter_test/flutter_test.dart';

/// Assertion helper: verifies actions executed in expected order
void assertActionsExecutedInOrder(List<String> expected, List<String> actual) {
  expect(
    actual.length,
    expected.length,
    reason:
        'Action count mismatch: expected ${expected.length}, got ${actual.length}',
  );
  for (var i = 0; i < expected.length; i++) {
    expect(
      actual[i],
      expected[i],
      reason:
          'Action at index $i: expected "${expected[i]}", got "${actual[i]}"',
    );
  }
}

/// Assertion helper: verifies exactly one occurrence of expected item
void assertExactlyOnce<T>(List<T> calls, T expected) {
  final count = calls.where((c) => c == expected).length;
  expect(
    count,
    1,
    reason: 'Expected exactly 1 occurrence of $expected, found $count',
  );
}

/// Assertion helper: verifies cooldown was respected between triggers
void assertCooldownRespected(
  DateTime first,
  DateTime second,
  Duration cooldown,
) {
  final diff = second.difference(first);
  expect(
    diff >= cooldown,
    isTrue,
    reason:
        'Cooldown not respected: only ${diff.inSeconds}s between triggers, '
        'expected at least ${cooldown.inSeconds}s',
  );
}

/// Assertion helper: verifies message contains all expected substrings
void assertMessageContainsAll(String message, List<String> expected) {
  for (final substring in expected) {
    expect(
      message.contains(substring),
      isTrue,
      reason: 'Message "$message" should contain "$substring"',
    );
  }
}

/// Assertion helper: verifies message does not contain any of the substrings
void assertMessageContainsNone(String message, List<String> unexpected) {
  for (final substring in unexpected) {
    expect(
      message.contains(substring),
      isFalse,
      reason: 'Message "$message" should NOT contain "$substring"',
    );
  }
}

/// Matcher for automation log entries
Matcher hasLogEntry({
  String? automationId,
  String? automationName,
  bool? success,
  List<String>? actionsExecuted,
}) {
  return predicate<dynamic>((entry) {
    if (automationId != null && entry.automationId != automationId) {
      return false;
    }
    if (automationName != null && entry.automationName != automationName) {
      return false;
    }
    if (success != null && entry.success != success) {
      return false;
    }
    if (actionsExecuted != null) {
      if (entry.actionsExecuted.length != actionsExecuted.length) {
        return false;
      }
      for (var i = 0; i < actionsExecuted.length; i++) {
        if (entry.actionsExecuted[i] != actionsExecuted[i]) {
          return false;
        }
      }
    }
    return true;
  }, 'log entry matching criteria');
}

/// Creates a test node with minimal required fields
Map<String, dynamic> createTestNode({
  required int nodeNum,
  String? shortName,
  String? longName,
  int? batteryLevel,
  double? latitude,
  double? longitude,
  DateTime? lastHeard,
  int? snr,
}) {
  return {
    'nodeNum': nodeNum,
    'shortName': shortName ?? 'TST',
    'longName': longName ?? 'Test Node',
    'batteryLevel': batteryLevel,
    'latitude': latitude,
    'longitude': longitude,
    'lastHeard': lastHeard?.toIso8601String(),
    'snr': snr,
  };
}

/// Creates a test automation with minimal required fields
Map<String, dynamic> createTestAutomation({
  required String id,
  required String name,
  required String triggerType,
  Map<String, dynamic>? triggerConfig,
  List<Map<String, dynamic>>? actions,
  List<Map<String, dynamic>>? conditions,
  bool enabled = true,
}) {
  return {
    'id': id,
    'name': name,
    'enabled': enabled,
    'trigger': {'type': triggerType, 'config': triggerConfig ?? {}},
    'actions':
        actions ??
        [
          {
            'type': 'pushNotification',
            'config': {
              'notificationTitle': 'Test',
              'notificationBody': 'Test notification',
            },
          },
        ],
    'conditions': conditions,
    'createdAt': DateTime.now().toIso8601String(),
    'triggerCount': 0,
  };
}

/// Extension for creating test data quickly
extension TestDataExtension on DateTime {
  /// Returns this DateTime with time set to specific hour:minute
  DateTime atTime(int hour, int minute) {
    return DateTime(year, month, day, hour, minute);
  }

  /// Returns this DateTime offset by hours
  DateTime hoursAgo(int hours) => subtract(Duration(hours: hours));

  /// Returns this DateTime offset by minutes
  DateTime minutesAgo(int minutes) => subtract(Duration(minutes: minutes));
}
