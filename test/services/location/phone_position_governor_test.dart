// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/services/location/location_service.dart';
import 'package:socialmesh/services/location/phone_position_governor.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Minimal transport stub so ProtocolService can be instantiated.
class _FakeTransport extends DeviceTransport {
  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

  @override
  DeviceConnectionState get state => DeviceConnectionState.disconnected;

  @override
  Stream<DeviceConnectionState> get stateStream => const Stream.empty();

  @override
  Stream<List<int>> get dataStream => const Stream.empty();

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();

  @override
  Future<void> connect(DeviceInfo device) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {}
}

/// ProtocolService subclass that records `sendPosition` calls.
class _SpyProtocolService extends ProtocolService {
  final List<({double lat, double lon, int? alt})> sentPositions = [];

  _SpyProtocolService() : super(_FakeTransport());

  @override
  Future<void> sendPosition({
    required double latitude,
    required double longitude,
    int? altitude,
  }) async {
    sentPositions.add((lat: latitude, lon: longitude, alt: altitude));
  }
}

/// LocationService subclass that overrides GPS calls for testing.
class _TestableLocationService extends LocationService {
  Position? fakePosition;

  _TestableLocationService(
    super.protocolService, {
    super.isLocationSharingEnabled,
    super.governor,
    this.fakePosition,
  });

  @override
  Future<Position?> getCurrentPosition() async => fakePosition;

  @override
  Future<bool> checkPermissions() async => true;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Position _fakePosition({
  double latitude = 51.5074,
  double longitude = -0.1278,
  double altitude = 11.0,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    altitude: altitude,
    timestamp: DateTime.now(),
    accuracy: 5.0,
    altitudeAccuracy: 5.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );
}

/// Creates a governor with controllable sharing state and a spy protocol.
({PhonePositionGovernor governor, _SpyProtocolService protocol}) _makeGovernor({
  bool Function()? isEnabled,
}) {
  final protocol = _SpyProtocolService();
  final governor = PhonePositionGovernor(
    protocol,
    isLocationSharingEnabled: isEnabled,
  );
  return (governor: governor, protocol: protocol);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // A) providePhoneLocation gate — no packets when disabled
  // =========================================================================

  group('Invariant A: providePhoneLocation gate', () {
    test('blocks all reasons when isLocationSharingEnabled is null', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: null);

      for (final reason in PositionPublishReason.values) {
        final decision = await governor.requestPublish(
          latitude: 51.5074,
          longitude: -0.1278,
          reason: reason,
        );
        expect(
          decision,
          PublishDecision.blockedDisabled,
          reason: 'null callback should block ${reason.name}',
        );
      }

      expect(
        protocol.sentPositions,
        isEmpty,
        reason: 'No packets when sharing is null (default false)',
      );
    });

    test(
      'blocks all reasons when isLocationSharingEnabled returns false',
      () async {
        final (:governor, :protocol) = _makeGovernor(isEnabled: () => false);

        for (final reason in PositionPublishReason.values) {
          final decision = await governor.requestPublish(
            latitude: 51.5074,
            longitude: -0.1278,
            reason: reason,
          );
          expect(decision, PublishDecision.blockedDisabled);
        }

        expect(protocol.sentPositions, isEmpty);
      },
    );

    test('blocks timerTick when disabled', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => false);

      final decision = await governor.requestPublish(
        latitude: 51.5074,
        longitude: -0.1278,
        reason: PositionPublishReason.timerTick,
      );

      expect(decision, PublishDecision.blockedDisabled);
      expect(protocol.sentPositions, isEmpty);
    });

    test('blocks manualAction when disabled', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => false);

      final decision = await governor.requestPublish(
        latitude: 51.5074,
        longitude: -0.1278,
        reason: PositionPublishReason.manualAction,
      );

      expect(decision, PublishDecision.blockedDisabled);
      expect(protocol.sentPositions, isEmpty);
    });

    test('blocks lifecycleResume when disabled', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => false);

      final decision = await governor.requestPublish(
        latitude: 51.5074,
        longitude: -0.1278,
        reason: PositionPublishReason.lifecycleResume,
      );

      expect(decision, PublishDecision.blockedDisabled);
      expect(protocol.sentPositions, isEmpty);
    });

    test('blocks reconnect when disabled', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => false);

      final decision = await governor.requestPublish(
        latitude: 51.5074,
        longitude: -0.1278,
        reason: PositionPublishReason.reconnect,
      );

      expect(decision, PublishDecision.blockedDisabled);
      expect(protocol.sentPositions, isEmpty);
    });

    test('blocks widgetAction when disabled', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => false);

      final decision = await governor.requestPublish(
        latitude: 51.5074,
        longitude: -0.1278,
        reason: PositionPublishReason.widgetAction,
      );

      expect(decision, PublishDecision.blockedDisabled);
      expect(protocol.sentPositions, isEmpty);
    });

    test('blocks command when disabled', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => false);

      final decision = await governor.requestPublish(
        latitude: 51.5074,
        longitude: -0.1278,
        reason: PositionPublishReason.command,
      );

      expect(decision, PublishDecision.blockedDisabled);
      expect(protocol.sentPositions, isEmpty);
    });

    test(
      'gate is evaluated dynamically — toggling mid-session works',
      () async {
        var enabled = false;
        final (:governor, :protocol) = _makeGovernor(isEnabled: () => enabled);

        // Disabled → blocked
        var d = await governor.requestPublish(
          latitude: 51.5074,
          longitude: -0.1278,
          reason: PositionPublishReason.manualAction,
        );
        expect(d, PublishDecision.blockedDisabled);
        expect(protocol.sentPositions, isEmpty);

        // Enable → allowed
        enabled = true;
        d = await governor.requestPublish(
          latitude: 51.5074,
          longitude: -0.1278,
          reason: PositionPublishReason.manualAction,
        );
        expect(d, PublishDecision.allowed);
        expect(protocol.sentPositions, hasLength(1));

        // Disable again → blocked
        enabled = false;
        d = await governor.requestPublish(
          latitude: 52.0,
          longitude: -1.0,
          reason: PositionPublishReason.manualAction,
        );
        expect(d, PublishDecision.blockedDisabled);
        expect(
          protocol.sentPositions,
          hasLength(1),
          reason: 'Third call blocked — still 1',
        );
      },
    );
  });

  // =========================================================================
  // B) Distance gate — stationary phone does not repeatedly broadcast
  // =========================================================================

  group('Invariant B: distance gate for automatic reasons', () {
    test('same location repeatedly does not publish on timerTick', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      // First publish allowed (no previous position).
      final d1 = await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );
      expect(d1, PublishDecision.allowed);
      expect(protocol.sentPositions, hasLength(1));

      // Simulate enough time passing to clear the interval gate.
      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 600),
      );

      // Same location → distance gate blocks.
      final d2 = await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );
      expect(d2, PublishDecision.blockedDistance);
      expect(
        protocol.sentPositions,
        hasLength(1),
        reason: 'Stationary — second tick blocked by distance',
      );
    });

    test(
      'same location repeatedly does not publish on lifecycleResume',
      () async {
        final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

        final d1 = await governor.requestPublish(
          latitude: 38.7223,
          longitude: -9.1393,
          reason: PositionPublishReason.lifecycleResume,
        );
        expect(d1, PublishDecision.allowed);

        // Clear interval gate.
        governor.lastPublishedAtOverride = DateTime.now().subtract(
          const Duration(seconds: 600),
        );

        final d2 = await governor.requestPublish(
          latitude: 38.7223,
          longitude: -9.1393,
          reason: PositionPublishReason.lifecycleResume,
        );
        expect(d2, PublishDecision.blockedDistance);
        expect(protocol.sentPositions, hasLength(1));
      },
    );

    test('same location repeatedly does not publish on reconnect', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      final d1 = await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.reconnect,
      );
      expect(d1, PublishDecision.allowed);

      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 600),
      );

      final d2 = await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.reconnect,
      );
      expect(d2, PublishDecision.blockedDistance);
      expect(protocol.sentPositions, hasLength(1));
    });

    test('moving >150m allows publish on timerTick', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      // Lisbon
      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );

      // Clear interval gate.
      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 600),
      );

      // Move ~400m north (well over 150m threshold).
      final d2 = await governor.requestPublish(
        latitude: 38.7260,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );
      expect(d2, PublishDecision.allowed);
      expect(protocol.sentPositions, hasLength(2));
    });

    test('moving <150m blocks publish on timerTick', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );

      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 600),
      );

      // Move ~50m north (under 150m threshold).
      final d2 = await governor.requestPublish(
        latitude: 38.72275,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );
      expect(d2, PublishDecision.blockedDistance);
      expect(protocol.sentPositions, hasLength(1));
    });

    test('manual action bypasses distance gate', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.manualAction,
      );

      // Clear interval gate but keep same position.
      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 120),
      );

      // Same location, manual action — distance gate bypassed.
      final d2 = await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.manualAction,
      );
      expect(d2, PublishDecision.allowed);
      expect(protocol.sentPositions, hasLength(2));
    });

    test('widgetAction bypasses distance gate', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.widgetAction,
      );

      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 120),
      );

      final d2 = await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.widgetAction,
      );
      expect(d2, PublishDecision.allowed);
      expect(protocol.sentPositions, hasLength(2));
    });

    test('command bypasses distance gate', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.command,
      );

      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 120),
      );

      final d2 = await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.command,
      );
      expect(d2, PublishDecision.allowed);
      expect(protocol.sentPositions, hasLength(2));
    });
  });

  // =========================================================================
  // C) Time gate — publishes no more often than minInterval
  // =========================================================================

  group('Invariant C: time gate', () {
    test('auto reason blocked within 300s of last publish', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      // First publish.
      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );
      expect(protocol.sentPositions, hasLength(1));

      // Immediately try again at a different location (>150m away)
      // to ensure only the TIME gate blocks, not distance.
      final d2 = await governor.requestPublish(
        latitude: 39.0,
        longitude: -9.0,
        reason: PositionPublishReason.timerTick,
      );
      expect(d2, PublishDecision.blockedInterval);
      expect(protocol.sentPositions, hasLength(1));
    });

    test('auto reason allowed after 300s', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );

      // Simulate 301 seconds passing.
      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 301),
      );

      final d2 = await governor.requestPublish(
        latitude: 39.0,
        longitude: -9.0,
        reason: PositionPublishReason.timerTick,
      );
      expect(d2, PublishDecision.allowed);
      expect(protocol.sentPositions, hasLength(2));
    });

    test('lifecycleResume blocked within 300s', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );

      // 60 seconds later, resume — should be blocked (needs 300s).
      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 60),
      );

      final d2 = await governor.requestPublish(
        latitude: 39.0,
        longitude: -9.0,
        reason: PositionPublishReason.lifecycleResume,
      );
      expect(d2, PublishDecision.blockedInterval);
      expect(protocol.sentPositions, hasLength(1));
    });

    test('reconnect blocked within 300s', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );

      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 60),
      );

      final d2 = await governor.requestPublish(
        latitude: 39.0,
        longitude: -9.0,
        reason: PositionPublishReason.reconnect,
      );
      expect(d2, PublishDecision.blockedInterval);
      expect(protocol.sentPositions, hasLength(1));
    });

    test('manual action uses shorter 60s interval', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.manualAction,
      );

      // 30 seconds later → blocked (needs 60s).
      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 30),
      );

      final d2 = await governor.requestPublish(
        latitude: 39.0,
        longitude: -9.0,
        reason: PositionPublishReason.manualAction,
      );
      expect(d2, PublishDecision.blockedInterval);
      expect(protocol.sentPositions, hasLength(1));
    });

    test('manual action allowed after 60s', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.manualAction,
      );

      // 61 seconds later → allowed.
      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 61),
      );

      final d2 = await governor.requestPublish(
        latitude: 39.0,
        longitude: -9.0,
        reason: PositionPublishReason.manualAction,
      );
      expect(d2, PublishDecision.allowed);
      expect(protocol.sentPositions, hasLength(2));
    });

    test('widgetAction uses shorter 60s interval', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.widgetAction,
      );

      // 30s → blocked.
      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 30),
      );

      var d = await governor.requestPublish(
        latitude: 39.0,
        longitude: -9.0,
        reason: PositionPublishReason.widgetAction,
      );
      expect(d, PublishDecision.blockedInterval);

      // 61s → allowed.
      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 61),
      );

      d = await governor.requestPublish(
        latitude: 39.0,
        longitude: -9.0,
        reason: PositionPublishReason.widgetAction,
      );
      expect(d, PublishDecision.allowed);
    });

    test('command uses shorter 60s interval', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.command,
      );

      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 30),
      );

      var d = await governor.requestPublish(
        latitude: 39.0,
        longitude: -9.0,
        reason: PositionPublishReason.command,
      );
      expect(d, PublishDecision.blockedInterval);

      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 61),
      );

      d = await governor.requestPublish(
        latitude: 39.0,
        longitude: -9.0,
        reason: PositionPublishReason.command,
      );
      expect(d, PublishDecision.allowed);
    });

    test('first publish always allowed (no previous timestamp)', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      final d = await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );
      expect(d, PublishDecision.allowed);
      expect(protocol.sentPositions, hasLength(1));
    });

    test('first publish after reset always allowed', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );

      governor.reset();

      final d = await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );
      expect(d, PublishDecision.allowed);
      expect(protocol.sentPositions, hasLength(2));
    });
  });

  // =========================================================================
  // D) Burst prevention — multiple triggers cannot produce >1 publish
  // =========================================================================

  group('Invariant D: burst prevention', () {
    test(
      'reconnect + resume + timerTick cannot produce >1 in short window',
      () async {
        final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

        // Simulate reconnect completing — first publish allowed.
        final d1 = await governor.requestPublish(
          latitude: 38.7223,
          longitude: -9.1393,
          reason: PositionPublishReason.reconnect,
        );
        expect(d1, PublishDecision.allowed);

        // Immediately after: lifecycle resume fires.
        final d2 = await governor.requestPublish(
          latitude: 38.7223,
          longitude: -9.1393,
          reason: PositionPublishReason.lifecycleResume,
        );
        expect(d2, PublishDecision.blockedInterval);

        // Then a timer tick fires.
        final d3 = await governor.requestPublish(
          latitude: 38.7223,
          longitude: -9.1393,
          reason: PositionPublishReason.timerTick,
        );
        expect(d3, PublishDecision.blockedInterval);

        // Only 1 packet made it through.
        expect(
          protocol.sentPositions,
          hasLength(1),
          reason: 'Burst of 3 triggers must produce exactly 1 publish',
        );
      },
    );

    test(
      'stop → start → resume does not double-publish within minInterval',
      () async {
        final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

        // First publish on start.
        final d1 = await governor.requestPublish(
          latitude: 38.7223,
          longitude: -9.1393,
          reason: PositionPublishReason.lifecycleResume,
        );
        expect(d1, PublishDecision.allowed);

        // "Stop" the timer (this is simulated — governor state persists).
        // "Restart" with another lifecycleResume immediately.
        final d2 = await governor.requestPublish(
          latitude: 38.7223,
          longitude: -9.1393,
          reason: PositionPublishReason.lifecycleResume,
        );
        expect(d2, PublishDecision.blockedInterval);

        expect(protocol.sentPositions, hasLength(1));
      },
    );

    test('rapid manual actions blocked within 60s', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.manualAction,
      );

      // Rapid second manual action — blocked.
      final d2 = await governor.requestPublish(
        latitude: 39.0,
        longitude: -9.0,
        reason: PositionPublishReason.manualAction,
      );
      expect(d2, PublishDecision.blockedInterval);

      // Third manual action — still blocked.
      final d3 = await governor.requestPublish(
        latitude: 40.0,
        longitude: -8.0,
        reason: PositionPublishReason.manualAction,
      );
      expect(d3, PublishDecision.blockedInterval);

      expect(
        protocol.sentPositions,
        hasLength(1),
        reason: '3 rapid manual actions should produce 1 publish',
      );
    });

    test(
      'auto publish followed by immediate manual action is blocked',
      () async {
        final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

        // Auto publish.
        await governor.requestPublish(
          latitude: 38.7223,
          longitude: -9.1393,
          reason: PositionPublishReason.timerTick,
        );

        // Immediate manual action — still within 60s of last publish.
        final d2 = await governor.requestPublish(
          latitude: 39.0,
          longitude: -9.0,
          reason: PositionPublishReason.manualAction,
        );
        expect(d2, PublishDecision.blockedInterval);
        expect(protocol.sentPositions, hasLength(1));
      },
    );

    test(
      'manual action 61s after auto publish is allowed (manual uses 60s interval)',
      () async {
        final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

        await governor.requestPublish(
          latitude: 38.7223,
          longitude: -9.1393,
          reason: PositionPublishReason.timerTick,
        );

        governor.lastPublishedAtOverride = DateTime.now().subtract(
          const Duration(seconds: 61),
        );

        final d2 = await governor.requestPublish(
          latitude: 39.0,
          longitude: -9.0,
          reason: PositionPublishReason.manualAction,
        );
        expect(d2, PublishDecision.allowed);
        expect(protocol.sentPositions, hasLength(2));
      },
    );
  });

  // =========================================================================
  // E) State persistence across governor lifetime
  // =========================================================================

  group('Invariant E: state persistence', () {
    test('lastPublishedAt persists and prevents immediate spam', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );

      // Verify state was recorded.
      expect(governor.lastPublishedAt, isNotNull);
      expect(governor.lastPublishedLat, 38.7223);
      expect(governor.lastPublishedLon, -9.1393);
      expect(governor.publishCount, 1);

      // Subsequent request is blocked.
      final d2 = await governor.requestPublish(
        latitude: 39.0,
        longitude: -9.0,
        reason: PositionPublishReason.timerTick,
      );
      expect(d2, PublishDecision.blockedInterval);
      expect(governor.denyCount, 1);
    });

    test('reset clears all state', () async {
      final (:governor, protocol: _) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );

      governor.reset();

      expect(governor.lastPublishedAt, isNull);
      expect(governor.lastPublishedLat, isNull);
      expect(governor.lastPublishedLon, isNull);
      expect(governor.publishCount, 0);
      expect(governor.denyCount, 0);
    });

    test('setLastPublishedPosition allows testing state injection', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      governor.setLastPublishedPosition(38.7223, -9.1393);
      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 600),
      );

      // Same location — distance gate should block.
      final d = await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );
      expect(d, PublishDecision.blockedDistance);
      expect(protocol.sentPositions, isEmpty);
    });
  });

  // =========================================================================
  // Gate ordering — interval checked before distance
  // =========================================================================

  group('Gate ordering', () {
    test('interval gate checked before distance gate', () async {
      final (:governor, protocol: _) = _makeGovernor(isEnabled: () => true);

      // Publish once.
      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );

      // Immediately try again at the SAME location.
      // Should be blockedInterval, NOT blockedDistance.
      final d = await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );
      expect(
        d,
        PublishDecision.blockedInterval,
        reason: 'Time gate should be checked first, before distance',
      );
    });
  });

  // =========================================================================
  // Counters
  // =========================================================================

  group('Counters', () {
    test('publishCount and denyCount track correctly', () async {
      final (:governor, protocol: _) = _makeGovernor(isEnabled: () => true);

      expect(governor.publishCount, 0);
      expect(governor.denyCount, 0);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );
      expect(governor.publishCount, 1);
      expect(governor.denyCount, 0);

      // Immediate second — denied.
      await governor.requestPublish(
        latitude: 39.0,
        longitude: -9.0,
        reason: PositionPublishReason.timerTick,
      );
      expect(governor.publishCount, 1);
      expect(governor.denyCount, 1);

      // Third — also denied.
      await governor.requestPublish(
        latitude: 40.0,
        longitude: -8.0,
        reason: PositionPublishReason.reconnect,
      );
      expect(governor.publishCount, 1);
      expect(governor.denyCount, 2);
    });
  });

  // =========================================================================
  // Haversine sanity checks
  // =========================================================================

  group('Haversine distance calculation', () {
    test('zero distance for same coordinates', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 51.5074,
        longitude: -0.1278,
        reason: PositionPublishReason.timerTick,
      );

      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 600),
      );

      final d = await governor.requestPublish(
        latitude: 51.5074,
        longitude: -0.1278,
        reason: PositionPublishReason.timerTick,
      );
      expect(d, PublishDecision.blockedDistance);
    });

    test('known distance: London to Paris is ~340km', () async {
      // This is a sanity check that haversine works at all.
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      // London
      await governor.requestPublish(
        latitude: 51.5074,
        longitude: -0.1278,
        reason: PositionPublishReason.timerTick,
      );

      governor.lastPublishedAtOverride = DateTime.now().subtract(
        const Duration(seconds: 600),
      );

      // Paris — ~340km away, well over 150m.
      final d = await governor.requestPublish(
        latitude: 48.8566,
        longitude: 2.3522,
        reason: PositionPublishReason.timerTick,
      );
      expect(d, PublishDecision.allowed);
      expect(protocol.sentPositions, hasLength(2));
    });
  });

  // =========================================================================
  // LocationService integration — sendPositionOnce routes through governor
  // =========================================================================

  group('LocationService integration with governor', () {
    test(
      'sendPositionOnce routes through governor and returns decision',
      () async {
        final protocol = _SpyProtocolService();
        final governor = PhonePositionGovernor(
          protocol,
          isLocationSharingEnabled: () => true,
        );

        final service = _TestableLocationService(
          protocol,
          isLocationSharingEnabled: () => true,
          governor: governor,
          fakePosition: _fakePosition(latitude: 38.7223, longitude: -9.1393),
        );

        final d1 = await service.sendPositionOnce();
        expect(d1, PublishDecision.allowed);
        expect(protocol.sentPositions, hasLength(1));

        // Immediately again — blocked by interval.
        final d2 = await service.sendPositionOnce();
        expect(d2, PublishDecision.blockedInterval);
        expect(protocol.sentPositions, hasLength(1));
      },
    );

    test(
      'sendPositionOnce returns blockedDisabled when sharing is off',
      () async {
        final protocol = _SpyProtocolService();
        final governor = PhonePositionGovernor(
          protocol,
          isLocationSharingEnabled: () => false,
        );

        final service = _TestableLocationService(
          protocol,
          isLocationSharingEnabled: () => false,
          governor: governor,
          fakePosition: _fakePosition(),
        );

        final d = await service.sendPositionOnce();
        expect(d, PublishDecision.blockedDisabled);
        expect(protocol.sentPositions, isEmpty);
      },
    );

    test(
      'sendPositionOnce returns blockedNoPosition when GPS returns null',
      () async {
        final protocol = _SpyProtocolService();
        final governor = PhonePositionGovernor(
          protocol,
          isLocationSharingEnabled: () => true,
        );

        final service = _TestableLocationService(
          protocol,
          isLocationSharingEnabled: () => true,
          governor: governor,
          fakePosition: null,
        );

        final d = await service.sendPositionOnce();
        expect(d, PublishDecision.blockedNoPosition);
        expect(protocol.sentPositions, isEmpty);
      },
    );

    test('publishWithReason uses the specified reason', () async {
      final protocol = _SpyProtocolService();
      final governor = PhonePositionGovernor(
        protocol,
        isLocationSharingEnabled: () => true,
      );

      final service = _TestableLocationService(
        protocol,
        isLocationSharingEnabled: () => true,
        governor: governor,
        fakePosition: _fakePosition(latitude: 38.7223, longitude: -9.1393),
      );

      final d = await service.publishWithReason(
        PositionPublishReason.widgetAction,
      );
      expect(d, PublishDecision.allowed);
      expect(protocol.sentPositions, hasLength(1));
    });

    test(
      'publishKnownPosition sends provided coords through governor',
      () async {
        final protocol = _SpyProtocolService();
        final governor = PhonePositionGovernor(
          protocol,
          isLocationSharingEnabled: () => true,
        );

        final service = _TestableLocationService(
          protocol,
          isLocationSharingEnabled: () => true,
          governor: governor,
          fakePosition: _fakePosition(), // should NOT be used
        );

        final d = await service.publishKnownPosition(
          latitude: 40.0,
          longitude: -8.0,
          altitude: 100,
          reason: PositionPublishReason.command,
        );
        expect(d, PublishDecision.allowed);
        expect(protocol.sentPositions, hasLength(1));
        expect(protocol.sentPositions.first.lat, 40.0);
        expect(protocol.sentPositions.first.lon, -8.0);
        expect(protocol.sentPositions.first.alt, 100);
      },
    );

    test('LocationService.governor exposes the shared instance', () {
      final protocol = _SpyProtocolService();
      final governor = PhonePositionGovernor(
        protocol,
        isLocationSharingEnabled: () => true,
      );

      final service = _TestableLocationService(
        protocol,
        isLocationSharingEnabled: () => true,
        governor: governor,
      );

      expect(service.governor, same(governor));
    });

    test(
      'LocationService creates default governor when none injected',
      () async {
        final protocol = _SpyProtocolService();

        final service = _TestableLocationService(
          protocol,
          isLocationSharingEnabled: () => true,
          fakePosition: _fakePosition(latitude: 38.7223, longitude: -9.1393),
        );

        // Should have a governor (auto-created).
        expect(service.governor, isNotNull);

        // Should work through the auto-created governor.
        final d = await service.sendPositionOnce();
        expect(d, PublishDecision.allowed);
        expect(protocol.sentPositions, hasLength(1));
      },
    );
  });

  // =========================================================================
  // startLocationUpdates no longer sends immediate burst
  // =========================================================================

  group('LocationService startLocationUpdates burst prevention', () {
    test(
      'startLocationUpdates does not immediately publish if governor blocks',
      () async {
        final protocol = _SpyProtocolService();
        final governor = PhonePositionGovernor(
          protocol,
          isLocationSharingEnabled: () => true,
        );

        // Pre-seed a recent publish so the governor blocks the initial tick.
        governor.lastPublishedAtOverride = DateTime.now();
        governor.setLastPublishedPosition(38.7223, -9.1393);

        final service = _TestableLocationService(
          protocol,
          isLocationSharingEnabled: () => true,
          governor: governor,
          fakePosition: _fakePosition(latitude: 38.7223, longitude: -9.1393),
        );

        await service.startLocationUpdates();

        // No immediate publish because governor blocked it (interval + distance).
        expect(
          protocol.sentPositions,
          isEmpty,
          reason:
              'startLocationUpdates must not produce an immediate publish if governor blocks',
        );

        service.dispose();
      },
    );

    test(
      'startLocationUpdates publishes on initial tick if governor allows',
      () async {
        final protocol = _SpyProtocolService();
        final governor = PhonePositionGovernor(
          protocol,
          isLocationSharingEnabled: () => true,
        );

        // Fresh governor — no previous publish.
        final service = _TestableLocationService(
          protocol,
          isLocationSharingEnabled: () => true,
          governor: governor,
          fakePosition: _fakePosition(latitude: 38.7223, longitude: -9.1393),
        );

        await service.startLocationUpdates();

        // First-ever publish allowed.
        expect(protocol.sentPositions, hasLength(1));

        service.dispose();
      },
    );

    test(
      'startLocationUpdates does not start when sharing is disabled',
      () async {
        final protocol = _SpyProtocolService();
        final governor = PhonePositionGovernor(
          protocol,
          isLocationSharingEnabled: () => false,
        );

        final service = _TestableLocationService(
          protocol,
          isLocationSharingEnabled: () => false,
          governor: governor,
          fakePosition: _fakePosition(),
        );

        await service.startLocationUpdates();

        expect(service.isRunning, isFalse);
        expect(protocol.sentPositions, isEmpty);
      },
    );

    test(
      'multiple startLocationUpdates calls do not create duplicate timers',
      () async {
        final protocol = _SpyProtocolService();
        final governor = PhonePositionGovernor(
          protocol,
          isLocationSharingEnabled: () => true,
        );

        final service = _TestableLocationService(
          protocol,
          isLocationSharingEnabled: () => true,
          governor: governor,
          fakePosition: _fakePosition(latitude: 38.7223, longitude: -9.1393),
        );

        await service.startLocationUpdates();
        await service.startLocationUpdates(); // Should be a no-op.
        await service.startLocationUpdates(); // Should be a no-op.

        // Only one initial tick publish.
        expect(protocol.sentPositions, hasLength(1));
        expect(service.isRunning, isTrue);

        service.dispose();
      },
    );
  });

  // =========================================================================
  // Altitude passthrough
  // =========================================================================

  group('Altitude passthrough', () {
    test('altitude is forwarded to ProtocolService', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        altitude: 42,
        reason: PositionPublishReason.timerTick,
      );

      expect(protocol.sentPositions, hasLength(1));
      expect(protocol.sentPositions.first.alt, 42);
    });

    test('null altitude is forwarded as null', () async {
      final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

      await governor.requestPublish(
        latitude: 38.7223,
        longitude: -9.1393,
        reason: PositionPublishReason.timerTick,
      );

      expect(protocol.sentPositions, hasLength(1));
      expect(protocol.sentPositions.first.alt, isNull);
    });
  });

  // =========================================================================
  // Mixed-reason sequences
  // =========================================================================

  group('Mixed-reason sequences', () {
    test(
      'auto publish, then manual after 61s, then auto after 301s total',
      () async {
        final (:governor, :protocol) = _makeGovernor(isEnabled: () => true);

        // T=0: auto publish.
        final d1 = await governor.requestPublish(
          latitude: 38.7223,
          longitude: -9.1393,
          reason: PositionPublishReason.timerTick,
        );
        expect(d1, PublishDecision.allowed);

        // T=61s: manual publish (different location to avoid distance gate).
        governor.lastPublishedAtOverride = DateTime.now().subtract(
          const Duration(seconds: 61),
        );
        final d2 = await governor.requestPublish(
          latitude: 39.0,
          longitude: -9.0,
          reason: PositionPublishReason.manualAction,
        );
        expect(d2, PublishDecision.allowed);

        // T=120s after manual (total 181s from first auto): auto publish.
        // But manual was at T=61, so 120s after manual = T=181.
        // Auto needs 300s since last publish (which was manual at T=61s).
        // 181 - 61 = 120s < 300s → blocked.
        governor.lastPublishedAtOverride = DateTime.now().subtract(
          const Duration(seconds: 120),
        );
        final d3 = await governor.requestPublish(
          latitude: 40.0,
          longitude: -8.0,
          reason: PositionPublishReason.timerTick,
        );
        expect(d3, PublishDecision.blockedInterval);

        // T=301s after manual: auto publish allowed.
        governor.lastPublishedAtOverride = DateTime.now().subtract(
          const Duration(seconds: 301),
        );
        final d4 = await governor.requestPublish(
          latitude: 40.0,
          longitude: -8.0,
          reason: PositionPublishReason.timerTick,
        );
        expect(d4, PublishDecision.allowed);

        expect(protocol.sentPositions, hasLength(3));
      },
    );
  });
}
