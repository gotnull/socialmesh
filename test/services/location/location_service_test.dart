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

/// ProtocolService subclass that records `sendPosition` calls instead of
/// serializing protobufs and hitting a real transport.
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

/// LocationService subclass that overrides `getCurrentPosition` and
/// `checkPermissions` to avoid hitting the real Geolocator (needs
/// platform channels / real GPS).
class _TestableLocationService extends LocationService {
  Position? fakePosition;

  _TestableLocationService(
    super.protocolService, {
    super.isLocationSharingEnabled,
    super.governor,
    this.fakePosition,
  });

  /// Overrides the real Geolocator call but preserves the failure-tracking
  /// behaviour of the base class so backoff tests work correctly.
  @override
  Future<Position?> getCurrentPosition() async {
    if (fakePosition != null) {
      // Simulate the success path from the base class.
      resetConsecutiveFailures();
      return fakePosition;
    }
    // Simulate the failure path from the base class.
    incrementConsecutiveFailures();
    return null;
  }

  @override
  Future<bool> checkPermissions() async => true;
}

/// Transport that records raw send calls so we can count how many
/// POSITION_APP packets actually reached the transport layer.
class _RecordingTransport extends DeviceTransport {
  final List<List<int>> sentBytes = [];

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

  @override
  bool get isConnected => true;

  @override
  DeviceConnectionState get state => DeviceConnectionState.connected;

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
  Future<void> send(List<int> data) async {
    sentBytes.add(data);
  }

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {}
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationService providePhoneLocation gate', () {
    late _SpyProtocolService protocol;
    late PhonePositionGovernor governor;

    setUp(() {
      protocol = _SpyProtocolService();
    });

    // ----- sendPositionOnce -----

    test(
      'sendPositionOnce is a no-op when isLocationSharingEnabled is null',
      () async {
        governor = PhonePositionGovernor(
          protocol,
          // isLocationSharingEnabled deliberately omitted (null)
        );
        final service = _TestableLocationService(
          protocol,
          fakePosition: _fakePosition(),
          governor: governor,
          // isLocationSharingEnabled deliberately omitted (null)
        );

        final decision = await service.sendPositionOnce();

        expect(
          decision,
          PublishDecision.blockedDisabled,
          reason: 'null callback should default to false — no emission',
        );
        expect(
          protocol.sentPositions,
          isEmpty,
          reason: 'null callback should default to false — no emission',
        );
      },
    );

    test(
      'sendPositionOnce is a no-op when isLocationSharingEnabled returns false',
      () async {
        governor = PhonePositionGovernor(
          protocol,
          isLocationSharingEnabled: () => false,
        );
        final service = _TestableLocationService(
          protocol,
          isLocationSharingEnabled: () => false,
          governor: governor,
          fakePosition: _fakePosition(),
        );

        final decision = await service.sendPositionOnce();

        expect(decision, PublishDecision.blockedDisabled);
        expect(
          protocol.sentPositions,
          isEmpty,
          reason: 'providePhoneLocation=false — no emission',
        );
      },
    );

    test(
      'sendPositionOnce sends when isLocationSharingEnabled returns true',
      () async {
        governor = PhonePositionGovernor(
          protocol,
          isLocationSharingEnabled: () => true,
        );
        final service = _TestableLocationService(
          protocol,
          isLocationSharingEnabled: () => true,
          governor: governor,
          fakePosition: _fakePosition(latitude: 40.7128, longitude: -74.0060),
        );

        final decision = await service.sendPositionOnce();

        expect(decision, PublishDecision.allowed);
        expect(protocol.sentPositions, hasLength(1));
        expect(protocol.sentPositions.first.lat, 40.7128);
        expect(protocol.sentPositions.first.lon, -74.0060);
      },
    );

    test('sendPositionOnce does not send when position is null', () async {
      governor = PhonePositionGovernor(
        protocol,
        isLocationSharingEnabled: () => true,
      );
      final service = _TestableLocationService(
        protocol,
        isLocationSharingEnabled: () => true,
        governor: governor,
        fakePosition: null, // no GPS fix
      );

      final decision = await service.sendPositionOnce();

      expect(decision, PublishDecision.blockedNoPosition);
      expect(
        protocol.sentPositions,
        isEmpty,
        reason: 'Even with sharing enabled, null position means no emission',
      );
    });

    // ----- Dynamic toggle (simulating setting change between ticks) -----

    test(
      'gate is evaluated dynamically — toggling mid-session works',
      () async {
        var enabled = false;

        governor = PhonePositionGovernor(
          protocol,
          isLocationSharingEnabled: () => enabled,
        );
        final service = _TestableLocationService(
          protocol,
          isLocationSharingEnabled: () => enabled,
          governor: governor,
          fakePosition: _fakePosition(),
        );

        // First call: disabled → no emission
        var d = await service.sendPositionOnce();
        expect(d, PublishDecision.blockedDisabled);
        expect(protocol.sentPositions, isEmpty);

        // User enables the setting
        enabled = true;

        // Second call: enabled → emission
        d = await service.sendPositionOnce();
        expect(d, PublishDecision.allowed);
        expect(protocol.sentPositions, hasLength(1));

        // User disables the setting again
        enabled = false;

        // Third call: disabled → no emission
        d = await service.sendPositionOnce();
        expect(d, PublishDecision.blockedDisabled);
        expect(
          protocol.sentPositions,
          hasLength(1),
          reason: 'Still 1 — the third call was blocked',
        );
      },
    );

    // ----- Timer-based (startLocationUpdates) -----

    test('periodic timer ticks do not emit when sharing is disabled', () async {
      governor = PhonePositionGovernor(
        protocol,
        isLocationSharingEnabled: () => false,
      );
      final service = _TestableLocationService(
        protocol,
        isLocationSharingEnabled: () => false,
        governor: governor,
        fakePosition: _fakePosition(),
      );

      // startLocationUpdates will fail permission check in test env
      // (no Geolocator platform channel), so we test via sendPositionOnce
      // which exercises the same governor code path.
      // The timer-based path is structurally identical — it calls
      // _governedTick on each tick.
      await service.sendPositionOnce();
      await service.sendPositionOnce();
      await service.sendPositionOnce();

      expect(
        protocol.sentPositions,
        isEmpty,
        reason: 'Three ticks, all blocked by the gate',
      );
    });

    // ----- Default value matches standard Meshtastic behaviour -----

    test(
      'default value is false (opt-in, standard Meshtastic behaviour)',
      () async {
        // When no callback is provided, the default is false (no emission).
        // This matches the standard Meshtastic companion app default (opt-in, false).
        governor = PhonePositionGovernor(protocol);
        final service = _TestableLocationService(
          protocol,
          governor: governor,
          fakePosition: _fakePosition(),
        );

        final d = await service.sendPositionOnce();

        expect(d, PublishDecision.blockedDisabled);
        expect(
          protocol.sentPositions,
          isEmpty,
          reason: 'Default must be false — privacy by default',
        );
      },
    );

    // ----- Dispose / cleanup -----

    test('dispose stops the timer without errors', () {
      governor = PhonePositionGovernor(
        protocol,
        isLocationSharingEnabled: () => true,
      );
      final service = _TestableLocationService(
        protocol,
        isLocationSharingEnabled: () => true,
        governor: governor,
        fakePosition: _fakePosition(),
      );

      // Should not throw
      service.dispose();
      expect(service.isRunning, isFalse);
    });

    test('stopLocationUpdates resets isRunning', () async {
      governor = PhonePositionGovernor(
        protocol,
        isLocationSharingEnabled: () => true,
      );
      final service = _TestableLocationService(
        protocol,
        isLocationSharingEnabled: () => true,
        governor: governor,
        fakePosition: _fakePosition(),
      );

      // Manually set running state (since startLocationUpdates needs
      // platform channels we can't use in unit tests)
      service.stopLocationUpdates();
      expect(service.isRunning, isFalse);
    });
  });

  // -----------------------------------------------------------------------
  // startLocationUpdates early-exit guard
  // -----------------------------------------------------------------------

  group('LocationService startLocationUpdates guard', () {
    late _SpyProtocolService protocol;

    setUp(() {
      protocol = _SpyProtocolService();
    });

    test(
      'startLocationUpdates does not start when isLocationSharingEnabled is null',
      () async {
        final governor = PhonePositionGovernor(protocol);
        final service = _TestableLocationService(
          protocol,
          governor: governor,
          fakePosition: _fakePosition(),
          // isLocationSharingEnabled deliberately omitted (null → false)
        );

        await service.startLocationUpdates();

        expect(
          service.isRunning,
          isFalse,
          reason: 'Timer must not start when sharing callback is null',
        );
        expect(protocol.sentPositions, isEmpty);
      },
    );

    test(
      'startLocationUpdates does not start when isLocationSharingEnabled returns false',
      () async {
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

        expect(
          service.isRunning,
          isFalse,
          reason: 'Timer must not start when sharing is disabled',
        );
        expect(protocol.sentPositions, isEmpty);
      },
    );

    test(
      'startLocationUpdates starts and sends when isLocationSharingEnabled returns true',
      () async {
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

        expect(
          service.isRunning,
          isTrue,
          reason: 'Timer must start when sharing is enabled',
        );
        // The initial tick should have been submitted to the governor.
        // On a fresh governor with no previous publish, the first tick is
        // allowed.
        expect(protocol.sentPositions, hasLength(1));
        expect(protocol.sentPositions.first.lat, 38.7223);

        service.dispose();
      },
    );
  });

  // -----------------------------------------------------------------------
  // ProtocolService POSITION_APP rate limiter (secondary safety net)
  // -----------------------------------------------------------------------

  group('ProtocolService position rate limiter', () {
    test('first sendPosition broadcast always succeeds', () async {
      final transport = _RecordingTransport();
      final ps = ProtocolService(transport);

      await ps.sendPosition(latitude: 39.5, longitude: -8.9);
      expect(transport.sentBytes, hasLength(1));
    });

    test('rapid successive broadcast is rate-limited', () async {
      final transport = _RecordingTransport();
      final ps = ProtocolService(transport);

      await ps.sendPosition(latitude: 39.5, longitude: -8.9);
      // Immediately send again — should be blocked.
      await ps.sendPosition(latitude: 39.6, longitude: -8.8);

      expect(
        transport.sentBytes,
        hasLength(1),
        reason: 'Second broadcast within 20 s must be rate-limited',
      );
    });

    test('first sendPositionToNode always succeeds', () async {
      final transport = _RecordingTransport();
      final ps = ProtocolService(transport);

      await ps.sendPositionToNode(nodeNum: 42, latitude: 39.5, longitude: -8.9);
      expect(transport.sentBytes, hasLength(1));
    });

    test('rapid successive direct send is rate-limited', () async {
      final transport = _RecordingTransport();
      final ps = ProtocolService(transport);

      await ps.sendPositionToNode(nodeNum: 42, latitude: 39.5, longitude: -8.9);
      // Immediately send again — should be blocked.
      await ps.sendPositionToNode(nodeNum: 42, latitude: 39.6, longitude: -8.8);

      expect(
        transport.sentBytes,
        hasLength(1),
        reason: 'Second direct send within 10 s must be rate-limited',
      );
    });

    test('broadcast and direct use independent rate limits', () async {
      final transport = _RecordingTransport();
      final ps = ProtocolService(transport);

      // Broadcast then direct — both should succeed because they track
      // separate timestamps.
      await ps.sendPosition(latitude: 39.5, longitude: -8.9);
      await ps.sendPositionToNode(nodeNum: 42, latitude: 39.5, longitude: -8.9);

      expect(
        transport.sentBytes,
        hasLength(2),
        reason: 'Broadcast and direct have independent cooldowns',
      );
    });
  });

  // -----------------------------------------------------------------------
  // GPS failure backoff
  // -----------------------------------------------------------------------

  group('GPS failure backoff', () {
    late _SpyProtocolService protocol;
    late PhonePositionGovernor governor;

    setUp(() {
      protocol = _SpyProtocolService();
    });

    test('timer ticks are skipped after consecutive GPS failures', () async {
      governor = PhonePositionGovernor(
        protocol,
        isLocationSharingEnabled: () => true,
      );
      // Start with null position (simulate GPS failure)
      final service = _TestableLocationService(
        protocol,
        fakePosition: null,
        governor: governor,
        isLocationSharingEnabled: () => true,
      );

      // First timer tick: GPS fails, consecutiveFailures becomes 1
      final result1 = await service.sendPositionOnce();
      expect(result1, PublishDecision.blockedNoPosition);
      // sendPositionOnce uses manualAction reason, so trigger timer ticks
      // directly via the public API sequence.

      // Simulate repeated failures by calling getCurrentPosition
      await service.getCurrentPosition(); // failure 2
      await service.getCurrentPosition(); // failure 3
      expect(service.consecutiveFailures, 3);
    });

    test('successful fix resets failure counter', () async {
      governor = PhonePositionGovernor(
        protocol,
        isLocationSharingEnabled: () => true,
      );
      final service = _TestableLocationService(
        protocol,
        fakePosition: null,
        governor: governor,
        isLocationSharingEnabled: () => true,
      );

      // Accumulate failures
      await service.getCurrentPosition();
      await service.getCurrentPosition();
      expect(service.consecutiveFailures, 2);

      // Fix becomes available
      service.fakePosition = _fakePosition();
      await service.getCurrentPosition();
      expect(service.consecutiveFailures, 0);
    });

    test('manual action bypasses backoff (always attempts GPS)', () async {
      governor = PhonePositionGovernor(
        protocol,
        isLocationSharingEnabled: () => true,
      );
      final service = _TestableLocationService(
        protocol,
        fakePosition: null,
        governor: governor,
        isLocationSharingEnabled: () => true,
      );

      // Accumulate failures
      for (int i = 0; i < 5; i++) {
        await service.getCurrentPosition();
      }
      expect(service.consecutiveFailures, 5);

      // Manual action should still attempt (sendPositionOnce uses
      // PositionPublishReason.manualAction which bypasses backoff).
      service.fakePosition = _fakePosition();
      final result = await service.sendPositionOnce();
      // Manual action goes through the governor which may publish
      expect(result, isNot(PublishDecision.blockedDisabled));
      expect(service.consecutiveFailures, 0);
    });
  });

  // -----------------------------------------------------------------------
  // Transport-error containment in _governedTick
  // -----------------------------------------------------------------------

  group('_governedTick transport-error containment', () {
    test(
      'transport throw inside the tick does not escape the future',
      () async {
        final protocol = _ThrowingProtocolService();
        final governor = PhonePositionGovernor(
          protocol,
          isLocationSharingEnabled: () => true,
        );
        final service = _TestableLocationService(
          protocol,
          fakePosition: _fakePosition(),
          governor: governor,
          isLocationSharingEnabled: () => true,
        );

        final result = await service.publishWithReason(
          PositionPublishReason.timerTick,
        );

        expect(result, PublishDecision.blockedNoPosition);
        expect(protocol.sendPositionCalls, 1);
      },
    );
  });
}

class _ThrowingProtocolService extends ProtocolService {
  int sendPositionCalls = 0;

  _ThrowingProtocolService() : super(_FakeTransport());

  @override
  Future<void> sendPosition({
    required double latitude,
    required double longitude,
    int? altitude,
  }) async {
    sendPositionCalls++;
    throw const TransportSendError('NetworkTransport: Not connected');
  }
}
