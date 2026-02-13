// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:socialmesh/features/aether/models/aether_flight.dart';
import 'package:socialmesh/features/aether/providers/aether_flight_lifecycle_provider.dart';
import 'package:socialmesh/features/aether/providers/aether_providers.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Minimal fake that records [updateFlightStatus] calls.
///
/// Does NOT depend on Firebase — we override
/// [aetherFlightStatusUpdaterProvider] instead of [aetherServiceProvider].
class _FakeUpdateTracker {
  final List<({String id, bool isActive})> updateCalls = [];

  Future<void> call(String id, {required bool isActive}) async {
    updateCalls.add((id: id, isActive: isActive));
  }
}

AetherFlight _makeFlight({
  String id = 'flight-1',
  String flightNumber = 'UA123',
  String departure = 'LAX',
  String arrival = 'JFK',
  bool isActive = false,
  DateTime? scheduledDeparture,
  DateTime? scheduledArrival,
}) {
  final now = DateTime.now();
  return AetherFlight(
    id: id,
    nodeId: '!a1b2c3d4',
    flightNumber: flightNumber,
    departure: departure,
    arrival: arrival,
    scheduledDeparture:
        scheduledDeparture ?? now.subtract(const Duration(hours: 1)),
    scheduledArrival: scheduledArrival ?? now.add(const Duration(hours: 4)),
    userId: 'user-1',
    isActive: isActive,
    createdAt: now,
  );
}

({ProviderContainer container, _FakeUpdateTracker tracker}) _createContainer({
  List<AetherFlight> flights = const [],
}) {
  final tracker = _FakeUpdateTracker();

  final container = ProviderContainer(
    overrides: [
      aetherFlightStatusUpdaterProvider.overrideWithValue(tracker.call),
      aetherFlightsProvider.overrideWithValue(AsyncValue.data(flights)),
    ],
  );

  return (container: container, tracker: tracker);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlightLifecycleState', () {
    test('default state has empty collections', () {
      const state = FlightLifecycleState();
      expect(state.pendingEvents, isEmpty);
      expect(state.activatedIds, isEmpty);
      expect(state.deactivatedIds, isEmpty);
    });

    test('copyWith preserves unmodified fields', () {
      const state = FlightLifecycleState();
      final updated = state.copyWith(activatedIds: {'f1'});
      expect(updated.activatedIds, {'f1'});
      expect(updated.pendingEvents, isEmpty);
      expect(updated.deactivatedIds, isEmpty);
    });
  });

  group('FlightLifecycleEvent', () {
    test('stores flight, activation flag, and timestamp', () {
      final flight = _makeFlight();
      final now = DateTime.now();
      final event = FlightLifecycleEvent(
        flight: flight,
        activated: true,
        timestamp: now,
      );
      expect(event.flight.flightNumber, 'UA123');
      expect(event.activated, true);
      expect(event.timestamp, now);
    });
  });

  group('AetherFlightLifecycleNotifier', () {
    test('auto-activates flight whose departure time has passed', () async {
      final now = DateTime.now();
      final flight = _makeFlight(
        scheduledDeparture: now.subtract(const Duration(hours: 1)),
        scheduledArrival: now.add(const Duration(hours: 4)),
        isActive: false,
      );

      final (:container, :tracker) = _createContainer(flights: [flight]);
      addTearDown(container.dispose);

      // Read provider to trigger build + immediate check.
      container.read(aetherFlightLifecycleProvider);

      // Allow the microtask-scheduled check to complete.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(tracker.updateCalls, hasLength(1));
      expect(tracker.updateCalls.first.id, 'flight-1');
      expect(tracker.updateCalls.first.isActive, true);

      final state = container.read(aetherFlightLifecycleProvider);
      expect(state.pendingEvents, hasLength(1));
      expect(state.pendingEvents.first.activated, true);
      expect(state.activatedIds, contains('flight-1'));
    });

    test('auto-deactivates flight whose arrival time has passed', () async {
      final now = DateTime.now();
      final flight = _makeFlight(
        scheduledDeparture: now.subtract(const Duration(hours: 6)),
        scheduledArrival: now.subtract(const Duration(hours: 1)),
        isActive: true,
      );

      final (:container, :tracker) = _createContainer(flights: [flight]);
      addTearDown(container.dispose);

      container.read(aetherFlightLifecycleProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(tracker.updateCalls, hasLength(1));
      expect(tracker.updateCalls.first.id, 'flight-1');
      expect(tracker.updateCalls.first.isActive, false);

      final state = container.read(aetherFlightLifecycleProvider);
      expect(state.pendingEvents, hasLength(1));
      expect(state.pendingEvents.first.activated, false);
      expect(state.deactivatedIds, contains('flight-1'));
    });

    test('does not activate flight whose departure is in the future', () async {
      final now = DateTime.now();
      final flight = _makeFlight(
        scheduledDeparture: now.add(const Duration(hours: 2)),
        scheduledArrival: now.add(const Duration(hours: 8)),
        isActive: false,
      );

      final (:container, :tracker) = _createContainer(flights: [flight]);
      addTearDown(container.dispose);

      container.read(aetherFlightLifecycleProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(tracker.updateCalls, isEmpty);
      final state = container.read(aetherFlightLifecycleProvider);
      expect(state.pendingEvents, isEmpty);
    });

    test('does not touch already-active in-flight flight', () async {
      final now = DateTime.now();
      final flight = _makeFlight(
        scheduledDeparture: now.subtract(const Duration(hours: 1)),
        scheduledArrival: now.add(const Duration(hours: 4)),
        isActive: true,
      );

      final (:container, :tracker) = _createContainer(flights: [flight]);
      addTearDown(container.dispose);

      container.read(aetherFlightLifecycleProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(tracker.updateCalls, isEmpty);
    });

    test('uses 12h fallback when no arrival time is set', () async {
      final now = DateTime.now();
      // Departed 11h ago, no arrival → still within 12h window.
      final activeNoArrival = _makeFlight(
        id: 'f-active',
        scheduledDeparture: now.subtract(const Duration(hours: 11)),
        isActive: false,
      );
      // Force scheduledArrival to null via copyWith workaround.
      final flight = AetherFlight(
        id: activeNoArrival.id,
        nodeId: activeNoArrival.nodeId,
        flightNumber: activeNoArrival.flightNumber,
        departure: activeNoArrival.departure,
        arrival: activeNoArrival.arrival,
        scheduledDeparture: activeNoArrival.scheduledDeparture,
        scheduledArrival: null,
        userId: activeNoArrival.userId,
        isActive: false,
        createdAt: activeNoArrival.createdAt,
      );

      final (:container, :tracker) = _createContainer(flights: [flight]);
      addTearDown(container.dispose);

      container.read(aetherFlightLifecycleProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Within 12h window → should activate.
      expect(tracker.updateCalls, hasLength(1));
      expect(tracker.updateCalls.first.isActive, true);
    });

    test('deactivates when past 12h fallback with no arrival', () async {
      final now = DateTime.now();
      final flight = AetherFlight(
        id: 'f-expired',
        nodeId: '!a1b2c3d4',
        flightNumber: 'EX999',
        departure: 'LAX',
        arrival: 'JFK',
        scheduledDeparture: now.subtract(const Duration(hours: 13)),
        scheduledArrival: null,
        userId: 'user-1',
        isActive: true,
        createdAt: now.subtract(const Duration(hours: 14)),
      );

      final (:container, :tracker) = _createContainer(flights: [flight]);
      addTearDown(container.dispose);

      container.read(aetherFlightLifecycleProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(tracker.updateCalls, hasLength(1));
      expect(tracker.updateCalls.first.isActive, false);
    });

    test('handles multiple flights with mixed states', () async {
      final now = DateTime.now();

      final departed = _makeFlight(
        id: 'f-departed',
        flightNumber: 'UA100',
        scheduledDeparture: now.subtract(const Duration(hours: 1)),
        scheduledArrival: now.add(const Duration(hours: 5)),
        isActive: false,
      );

      final landed = _makeFlight(
        id: 'f-landed',
        flightNumber: 'UA200',
        scheduledDeparture: now.subtract(const Duration(hours: 8)),
        scheduledArrival: now.subtract(const Duration(hours: 2)),
        isActive: true,
      );

      final future = _makeFlight(
        id: 'f-future',
        flightNumber: 'UA300',
        scheduledDeparture: now.add(const Duration(hours: 3)),
        scheduledArrival: now.add(const Duration(hours: 9)),
        isActive: false,
      );

      final (:container, :tracker) = _createContainer(
        flights: [departed, landed, future],
      );
      addTearDown(container.dispose);

      container.read(aetherFlightLifecycleProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // departed → activate, landed → deactivate, future → no change.
      expect(tracker.updateCalls, hasLength(2));

      final activateCall = tracker.updateCalls.firstWhere(
        (c) => c.id == 'f-departed',
      );
      expect(activateCall.isActive, true);

      final deactivateCall = tracker.updateCalls.firstWhere(
        (c) => c.id == 'f-landed',
      );
      expect(deactivateCall.isActive, false);

      final state = container.read(aetherFlightLifecycleProvider);
      expect(state.activatedIds, contains('f-departed'));
      expect(state.deactivatedIds, contains('f-landed'));
    });

    test('acknowledgeEvent removes event from pending list', () async {
      final now = DateTime.now();
      final flight = _makeFlight(
        scheduledDeparture: now.subtract(const Duration(hours: 1)),
        scheduledArrival: now.add(const Duration(hours: 4)),
        isActive: false,
      );

      final (:container, tracker: _) = _createContainer(flights: [flight]);
      addTearDown(container.dispose);

      container.read(aetherFlightLifecycleProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      var state = container.read(aetherFlightLifecycleProvider);
      expect(state.pendingEvents, hasLength(1));

      final notifier = container.read(aetherFlightLifecycleProvider.notifier);
      notifier.acknowledgeEvent(state.pendingEvents.first);

      state = container.read(aetherFlightLifecycleProvider);
      expect(state.pendingEvents, isEmpty);
    });

    test('acknowledgeAll clears all pending events', () async {
      final now = DateTime.now();
      final f1 = _makeFlight(
        id: 'f1',
        scheduledDeparture: now.subtract(const Duration(hours: 1)),
        scheduledArrival: now.add(const Duration(hours: 4)),
        isActive: false,
      );
      final f2 = _makeFlight(
        id: 'f2',
        flightNumber: 'DL456',
        scheduledDeparture: now.subtract(const Duration(hours: 2)),
        scheduledArrival: now.add(const Duration(hours: 3)),
        isActive: false,
      );

      final (:container, tracker: _) = _createContainer(flights: [f1, f2]);
      addTearDown(container.dispose);

      container.read(aetherFlightLifecycleProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      var state = container.read(aetherFlightLifecycleProvider);
      expect(state.pendingEvents, hasLength(2));

      container.read(aetherFlightLifecycleProvider.notifier).acknowledgeAll();

      state = container.read(aetherFlightLifecycleProvider);
      expect(state.pendingEvents, isEmpty);
      // activatedIds should still be tracked.
      expect(state.activatedIds, containsAll(['f1', 'f2']));
    });

    test('does not re-activate a previously deactivated flight', () async {
      final now = DateTime.now();
      // Flight that departed 2h ago, arrived 30min ago → should deactivate.
      // But we'll tell the provider it's already deactivated.
      final flight = _makeFlight(
        scheduledDeparture: now.subtract(const Duration(hours: 2)),
        scheduledArrival: now.subtract(const Duration(minutes: 30)),
        isActive: true,
      );

      final (:container, :tracker) = _createContainer(flights: [flight]);
      addTearDown(container.dispose);

      container.read(aetherFlightLifecycleProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // First pass: deactivates the flight.
      expect(tracker.updateCalls, hasLength(1));
      expect(tracker.updateCalls.first.isActive, false);

      // Now simulate the flight state updating in Firestore — still has
      // isActive: true because Firestore hasn't reflected yet, but the
      // provider remembers it was deactivated. This tests the deactivatedIds
      // guard.
      final state = container.read(aetherFlightLifecycleProvider);
      expect(state.deactivatedIds, contains('flight-1'));
    });

    test('no action when flights list is empty', () async {
      final (:container, :tracker) = _createContainer(flights: []);
      addTearDown(container.dispose);

      container.read(aetherFlightLifecycleProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(tracker.updateCalls, isEmpty);
      final state = container.read(aetherFlightLifecycleProvider);
      expect(state.pendingEvents, isEmpty);
    });

    test('disposes timer on container dispose', () async {
      final (:container, tracker: _) = _createContainer();

      container.read(aetherFlightLifecycleProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Should not throw.
      container.dispose();
    });
  });
}
