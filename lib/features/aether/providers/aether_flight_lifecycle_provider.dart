// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';

import '../models/aether_flight.dart';
import 'aether_providers.dart';

/// How often the lifecycle provider checks flight status (seconds).
const int _checkIntervalSeconds = 60;

/// Maximum flight duration assumed when no arrival time is set.
const Duration _maxFlightDuration = Duration(hours: 12);

/// Signature for the function that updates a flight's `isActive` in
/// Firestore. Extracted into its own provider so tests can override it
/// without needing a full Firebase environment.
typedef FlightStatusUpdater =
    Future<void> Function(String id, {required bool isActive});

/// Provider for the flight status updater function.
///
/// In production this delegates to [AetherService.updateFlightStatus].
/// In tests, override this provider with a fake tracker.
final aetherFlightStatusUpdaterProvider = Provider<FlightStatusUpdater>((ref) {
  final service = ref.read(aetherServiceProvider);
  return (String id, {required bool isActive}) =>
      service.updateFlightStatus(id, isActive: isActive);
});

/// State emitted by [AetherFlightLifecycleNotifier].
///
/// Tracks which flights were activated/deactivated so MainShell can
/// react (e.g., show a snackbar or push notification).
class FlightLifecycleEvent {
  /// Flight that just had its status changed.
  final AetherFlight flight;

  /// Whether the flight was activated (`true`) or deactivated (`false`).
  final bool activated;

  /// When the event occurred.
  final DateTime timestamp;

  const FlightLifecycleEvent({
    required this.flight,
    required this.activated,
    required this.timestamp,
  });
}

/// Accumulated state for the lifecycle notifier.
class FlightLifecycleState {
  /// Events that haven't been acknowledged by the UI yet.
  final List<FlightLifecycleEvent> pendingEvents;

  /// IDs of flights currently managed (to avoid duplicate transitions).
  final Set<String> activatedIds;

  /// IDs of flights we've already deactivated (prevent re-deactivation).
  final Set<String> deactivatedIds;

  const FlightLifecycleState({
    this.pendingEvents = const [],
    this.activatedIds = const {},
    this.deactivatedIds = const {},
  });

  FlightLifecycleState copyWith({
    List<FlightLifecycleEvent>? pendingEvents,
    Set<String>? activatedIds,
    Set<String>? deactivatedIds,
  }) {
    return FlightLifecycleState(
      pendingEvents: pendingEvents ?? this.pendingEvents,
      activatedIds: activatedIds ?? this.activatedIds,
      deactivatedIds: deactivatedIds ?? this.deactivatedIds,
    );
  }
}

/// Background provider that auto-activates flights whose departure time
/// has passed and auto-deactivates flights whose arrival time (or
/// departure + 12h) has passed.
///
/// Runs every [_checkIntervalSeconds] seconds while watched. Wire this
/// into MainShell so it operates for the lifetime of the app.
class AetherFlightLifecycleNotifier extends Notifier<FlightLifecycleState> {
  Timer? _timer;

  @override
  FlightLifecycleState build() {
    // Start the periodic check timer.
    _timer = Timer.periodic(
      const Duration(seconds: _checkIntervalSeconds),
      (_) => _checkFlights(),
    );
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });

    // Run an immediate check on build.
    Future.microtask(_checkFlights);

    return const FlightLifecycleState();
  }

  /// Mark a lifecycle event as acknowledged so it won't be emitted again.
  void acknowledgeEvent(FlightLifecycleEvent event) {
    AppLogging.aether(
      'Lifecycle: acknowledged ${event.activated ? 'activation' : 'deactivation'} '
      'of ${event.flight.flightNumber}',
    );
    final updated = List<FlightLifecycleEvent>.from(state.pendingEvents)
      ..remove(event);
    state = state.copyWith(pendingEvents: updated);
  }

  /// Clear all pending events.
  void acknowledgeAll() {
    AppLogging.aether(
      'Lifecycle: acknowledgeAll() — clearing ${state.pendingEvents.length} events',
    );
    state = state.copyWith(pendingEvents: []);
  }

  /// Core logic: scan flights and toggle isActive as needed.
  ///
  /// Only updates flights owned by the current user to avoid
  /// Firestore PERMISSION_DENIED errors on other users' flights.
  Future<void> _checkFlights() async {
    final flightsAsync = ref.read(aetherFlightsProvider);
    final flights = flightsAsync.value;
    if (flights == null || flights.isEmpty) return;

    final currentUid = ref.read(aetherCurrentUserIdProvider);
    if (currentUid == null) return;

    final myFlights = flights.where((f) => f.userId == currentUid).toList();
    if (myFlights.isEmpty) return;

    AppLogging.aether(
      'Lifecycle: _checkFlights() — scanning ${myFlights.length} of '
      '${flights.length} flights (own only)',
    );

    final now = DateTime.now();
    final updater = ref.read(aetherFlightStatusUpdaterProvider);
    final newEvents = <FlightLifecycleEvent>[];
    var activatedIds = Set<String>.from(state.activatedIds);
    var deactivatedIds = Set<String>.from(state.deactivatedIds);

    for (final flight in myFlights) {
      final shouldBeActive = _shouldBeActive(flight, now);

      if (shouldBeActive && !flight.isActive) {
        // Flight should be active but isn't — activate it.
        if (deactivatedIds.contains(flight.id)) {
          // We already deactivated this flight, don't re-activate.
          continue;
        }
        await _activateFlight(updater, flight);
        activatedIds = {...activatedIds, flight.id};
        newEvents.add(
          FlightLifecycleEvent(flight: flight, activated: true, timestamp: now),
        );
      } else if (!shouldBeActive && flight.isActive) {
        // Flight should no longer be active — deactivate it.
        await _deactivateFlight(updater, flight);
        activatedIds = {...activatedIds}..remove(flight.id);
        deactivatedIds = {...deactivatedIds, flight.id};
        newEvents.add(
          FlightLifecycleEvent(
            flight: flight,
            activated: false,
            timestamp: now,
          ),
        );
      }
    }

    if (newEvents.isNotEmpty) {
      state = state.copyWith(
        pendingEvents: [...state.pendingEvents, ...newEvents],
        activatedIds: activatedIds,
        deactivatedIds: deactivatedIds,
      );
    }
  }

  /// Determine if a flight should currently be active based on time.
  bool _shouldBeActive(AetherFlight flight, DateTime now) {
    // Not yet departed.
    if (now.isBefore(flight.scheduledDeparture)) return false;

    // Check arrival time.
    final effectiveArrival =
        flight.scheduledArrival ??
        flight.scheduledDeparture.add(_maxFlightDuration);

    // Past arrival — no longer active.
    if (now.isAfter(effectiveArrival)) return false;

    // Between departure and arrival — should be active.
    return true;
  }

  Future<void> _activateFlight(
    FlightStatusUpdater updater,
    AetherFlight flight,
  ) async {
    try {
      await updater(flight.id, isActive: true);
      AppLogging.aether(
        'Auto-activated flight ${flight.flightNumber} '
        '(departed ${flight.scheduledDeparture.toIso8601String()})',
      );
    } catch (e) {
      AppLogging.aether('Failed to auto-activate ${flight.flightNumber}: $e');
    }
  }

  Future<void> _deactivateFlight(
    FlightStatusUpdater updater,
    AetherFlight flight,
  ) async {
    try {
      await updater(flight.id, isActive: false);
      AppLogging.aether(
        'Auto-deactivated flight ${flight.flightNumber} '
        '(arrived/expired)',
      );
    } catch (e) {
      AppLogging.aether('Failed to auto-deactivate ${flight.flightNumber}: $e');
    }
  }
}

/// Provider for the flight lifecycle manager.
///
/// Watch this in MainShell to keep it alive and receive lifecycle events.
final aetherFlightLifecycleProvider =
    NotifierProvider<AetherFlightLifecycleNotifier, FlightLifecycleState>(
      AetherFlightLifecycleNotifier.new,
    );
