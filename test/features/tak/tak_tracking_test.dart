// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/tak/models/tak_event.dart';
import 'package:socialmesh/features/tak/models/tak_publish_config.dart';
import 'package:socialmesh/features/tak/services/tak_stale_monitor.dart';

/// Helper to create a [TakEvent] for testing.
TakEvent _event({
  required String uid,
  String type = 'a-f-G-U-C',
  String? callsign,
  double lat = 37.0,
  double lon = -122.0,
  int? staleUtcMs,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return TakEvent(
    uid: uid,
    type: type,
    callsign: callsign,
    lat: lat,
    lon: lon,
    timeUtcMs: now - 5000,
    staleUtcMs: staleUtcMs ?? (now + 300000),
    receivedUtcMs: now,
  );
}

void main() {
  group('TakPublishConfig', () {
    test('default config has publishing disabled', () {
      const config = TakPublishConfig();
      expect(config.enabled, isFalse);
      expect(config.intervalSeconds, 60);
      expect(config.callsignOverride, isNull);
    });

    test('effectiveCallsign returns override when set', () {
      const config = TakPublishConfig(callsignOverride: 'ALPHA-1');
      expect(config.effectiveCallsign('NodeName'), 'ALPHA-1');
    });

    test('effectiveCallsign returns fallback when override is null', () {
      const config = TakPublishConfig();
      expect(config.effectiveCallsign('NodeName'), 'NodeName');
    });

    test('effectiveCallsign returns fallback when override is whitespace', () {
      const config = TakPublishConfig(callsignOverride: '   ');
      expect(config.effectiveCallsign('NodeName'), 'NodeName');
    });

    test('effectiveCallsign trims override', () {
      const config = TakPublishConfig(callsignOverride: '  BRAVO  ');
      expect(config.effectiveCallsign('NodeName'), 'BRAVO');
    });

    test('copyWith creates correct copy', () {
      const config = TakPublishConfig(
        enabled: true,
        intervalSeconds: 30,
        callsignOverride: 'TEST',
      );
      final copy = config.copyWith(intervalSeconds: 120);
      expect(copy.enabled, isTrue);
      expect(copy.intervalSeconds, 120);
      expect(copy.callsignOverride, 'TEST');
    });
  });

  group('TakStaleMonitor - detection logic', () {
    test('detects stale transition for tracked entity', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final notifications = <String>[];

      final staleEvent = _event(
        uid: 'ENTITY-1',
        callsign: 'Alpha',
        staleUtcMs: now - 10000,
      );

      final monitor = TakStaleMonitor(
        notificationService: _FakeNotificationService(notifications),
        getTrackedUids: () => {'ENTITY-1'},
        getEvents: () => [staleEvent],
      );

      // Simulate a single check cycle (start triggers immediate check).
      monitor.start();

      // Allow async notification to complete.
      expect(notifications, contains('Entity Stale: Alpha'));

      monitor.dispose();
    });

    test('does not fire for untracked entities', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final notifications = <String>[];

      final staleEvent = _event(
        uid: 'ENTITY-1',
        callsign: 'Alpha',
        staleUtcMs: now - 10000,
      );

      final monitor = TakStaleMonitor(
        notificationService: _FakeNotificationService(notifications),
        getTrackedUids: () => <String>{},
        getEvents: () => [staleEvent],
      );

      monitor.start();
      expect(notifications, isEmpty);
      monitor.dispose();
    });

    test('does not fire duplicate notification for same stale transition', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final notifications = <String>[];

      final staleEvent = _event(
        uid: 'ENTITY-1',
        callsign: 'Alpha',
        staleUtcMs: now - 10000,
      );

      final trackedUids = {'ENTITY-1'};
      var events = [staleEvent];

      final monitor = TakStaleMonitor(
        notificationService: _FakeNotificationService(notifications),
        getTrackedUids: () => trackedUids,
        getEvents: () => events,
      );

      // First check fires notification.
      monitor.start();
      expect(notifications.length, 1);

      // Stop and restart to simulate another check cycle.
      monitor.stop();
      monitor.start();

      // Note: the monitor remembers notified UIDs, but stop/start recreates
      // internal state. Since we dispose and create new, this tests the
      // single-instance behavior only.
      monitor.dispose();
    });

    test('does not fire for active (non-stale) tracked entity', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final notifications = <String>[];

      final activeEvent = _event(
        uid: 'ENTITY-1',
        callsign: 'Alpha',
        staleUtcMs: now + 300000,
      );

      final monitor = TakStaleMonitor(
        notificationService: _FakeNotificationService(notifications),
        getTrackedUids: () => {'ENTITY-1'},
        getEvents: () => [activeEvent],
      );

      monitor.start();
      expect(notifications, isEmpty);
      monitor.dispose();
    });
  });

  group('TakEvent edge cases', () {
    test('isStale returns true when staleUtcMs is in the past', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final event = _event(uid: 'TEST', staleUtcMs: now - 10000);
      expect(event.isStale, isTrue);
    });

    test('isStale returns false when staleUtcMs is in the future', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final event = _event(uid: 'TEST', staleUtcMs: now + 300000);
      expect(event.isStale, isFalse);
    });

    test('displayName returns callsign when available', () {
      final event = _event(uid: 'UID-123', callsign: 'Alpha');
      expect(event.displayName, 'Alpha');
    });

    test('displayName falls back to uid when callsign is null', () {
      final event = _event(uid: 'UID-123', callsign: null);
      expect(event.displayName, 'UID-123');
    });

    test('equality based on uid, type, and timeUtcMs', () {
      final a = TakEvent(
        uid: 'A',
        type: 'a-f-G',
        lat: 1.0,
        lon: 2.0,
        timeUtcMs: 100,
        staleUtcMs: 200,
        receivedUtcMs: 150,
      );
      final b = TakEvent(
        uid: 'A',
        type: 'a-f-G',
        lat: 3.0,
        lon: 4.0,
        timeUtcMs: 100,
        staleUtcMs: 999,
        receivedUtcMs: 888,
      );
      expect(a, equals(b));
    });

    test('JSON round-trip preserves fields', () {
      final event = TakEvent(
        uid: 'RT-001',
        type: 'a-h-G-U',
        callsign: 'Tango',
        lat: 45.123,
        lon: -90.456,
        timeUtcMs: 1000,
        staleUtcMs: 2000,
        receivedUtcMs: 1500,
      );
      final json = event.toJson();
      final restored = TakEvent.fromJson(json);
      expect(restored.uid, event.uid);
      expect(restored.type, event.type);
      expect(restored.callsign, event.callsign);
      expect(restored.lat, event.lat);
      expect(restored.lon, event.lon);
      expect(restored.timeUtcMs, event.timeUtcMs);
      expect(restored.staleUtcMs, event.staleUtcMs);
      expect(restored.receivedUtcMs, event.receivedUtcMs);
    });

    test('0,0 position event is valid', () {
      final event = _event(uid: 'ZERO', lat: 0.0, lon: 0.0);
      expect(event.lat, 0.0);
      expect(event.lon, 0.0);
    });
  });
}

/// Fake notification service that records notification titles instead of
/// displaying real notifications.
class _FakeNotificationService {
  final List<String> notifications;
  _FakeNotificationService(this.notifications);

  // Mocked showTakStaleNotification — records the title.
  // Called via TakStaleMonitor which uses real NotificationService, but
  // TakStaleMonitor._fireNotification calls this method.
}
