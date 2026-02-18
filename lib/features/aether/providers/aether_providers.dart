// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';

import '../../../providers/auth_providers.dart';
import '../models/aether_flight.dart';
import '../services/aether_service.dart';
import '../services/aether_share_service.dart';

/// Current user UID for Aether lifecycle operations.
///
/// Derived from [currentUserProvider]. Tests can override this with a
/// simple string value instead of mocking [FirebaseAuth.User].
final aetherCurrentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.uid;
});

/// Provider for AetherService
final aetherServiceProvider = Provider<AetherService>((ref) {
  return AetherService();
});

/// Provider for AetherShareService (sharing flights to aether.socialmesh.app)
final aetherShareServiceProvider = Provider<AetherShareService>((ref) {
  return AetherShareService();
});

/// Provider for all flights (upcoming and active)
final aetherFlightsProvider = StreamProvider<List<AetherFlight>>((ref) {
  final service = ref.watch(aetherServiceProvider);
  return service.watchFlights();
});

/// Provider for active flights only
final aetherActiveFlightsProvider = StreamProvider<List<AetherFlight>>((ref) {
  final service = ref.watch(aetherServiceProvider);
  return service.watchActiveFlights();
});

/// Provider for reception reports for a specific flight
final aetherFlightReportsProvider =
    StreamProvider.family<List<ReceptionReport>, String>((ref, flightId) {
      final service = ref.watch(aetherServiceProvider);
      return service.watchReports(flightId);
    });

/// Provider for global leaderboard — all-time top distances
///
/// Fetches from the Aether REST API which aggregates all reception
/// reports globally. Falls back to Firestore if the API is unavailable.
final aetherGlobalLeaderboardProvider = FutureProvider<List<ReceptionReport>>((
  ref,
) async {
  AppLogging.aether('aetherGlobalLeaderboardProvider — fetching leaderboard');
  final shareService = ref.watch(aetherShareServiceProvider);
  try {
    final entries = await shareService.fetchLeaderboard(limit: 100);
    AppLogging.aether(
      'aetherGlobalLeaderboardProvider — got ${entries.length} entries',
    );
    return entries.map((e) => e.toReceptionReport()).toList();
  } catch (e) {
    // Fall back to Firestore stream if API is unavailable
    AppLogging.aether('API leaderboard failed, falling back to Firestore: $e');
    final service = ref.watch(aetherServiceProvider);
    return service.watchLeaderboard().first;
  }
});

/// State for flight position tracking
class FlightPositionState {
  final FlightPosition? position;
  final bool isLoading;
  final String? error;
  final DateTime? lastFetch;

  const FlightPositionState({
    this.position,
    this.isLoading = false,
    this.error,
    this.lastFetch,
  });

  FlightPositionState copyWith({
    FlightPosition? position,
    bool? isLoading,
    String? error,
    DateTime? lastFetch,
  }) {
    return FlightPositionState(
      position: position ?? this.position,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastFetch: lastFetch ?? this.lastFetch,
    );
  }
}

/// Provider for live flight position tracking.
///
/// Reads cached positions from the Aether API's server-side OpenSky cache.
/// The server polls OpenSky once per active flight every 60s and caches
/// results — clients never call OpenSky directly, so zero OpenSky credits
/// are consumed by the app regardless of user count.
///
/// Auto-refreshes every 30 seconds (cheap — just a GET to our own API).
final aetherFlightPositionProvider = FutureProvider.autoDispose
    .family<FlightPositionState, String>((ref, callsign) async {
      AppLogging.aether('aetherFlightPositionProvider — tracking $callsign');
      final shareService = ref.watch(aetherShareServiceProvider);

      // Poll our own API every 30 seconds — this is free (no OpenSky credits).
      // The server-side cache updates every 60s from OpenSky, so 30s client
      // polls give near-instant pickup of new data without waste.
      final timer = Timer.periodic(const Duration(seconds: 30), (_) {
        ref.invalidateSelf();
      });
      ref.onDispose(timer.cancel);

      try {
        final cached = await shareService.fetchFlightPosition(callsign);

        if (cached != null) {
          final pos = cached.position;
          AppLogging.aether(
            'Position update for $callsign (cached ${cached.stale ? "STALE" : "fresh"}): '
            'lat=${pos.latitude} lon=${pos.longitude} alt=${pos.altitude}m',
          );
          return FlightPositionState(
            position: pos,
            isLoading: false,
            lastFetch: cached.cachedAt,
          );
        }

        return FlightPositionState(isLoading: false, lastFetch: DateTime.now());
      } catch (e) {
        AppLogging.aether('Error fetching position for $callsign: $e');
        return FlightPositionState(isLoading: false, error: e.toString());
      }
    });

/// Stats provider for Aether
///
/// Uses the global leaderboard for accurate stats that persist
/// across app reinstalls and are consistent for all users.
final aetherStatsProvider = Provider<AetherStats>((ref) {
  final flights = ref.watch(aetherFlightsProvider);
  final activeFlights = ref.watch(aetherActiveFlightsProvider);
  final leaderboard = ref.watch(aetherGlobalLeaderboardProvider);

  // Get total report count from leaderboard (all reports with distance)
  final reports = leaderboard.value ?? [];
  final longestDistance = reports.isNotEmpty
      ? reports.first.estimatedDistance ?? 0
      : 0.0;

  // Merge both sources: aetherFlightsProvider has a 12h departure cutoff,
  // aetherActiveFlightsProvider catches flights that departed >12h ago.
  final recentFlights = flights.value ?? [];
  final activeFlightsList = activeFlights.value ?? [];
  final mergedById = <String, AetherFlight>{};
  for (final f in recentFlights) {
    mergedById[f.id] = f;
  }
  for (final f in activeFlightsList) {
    mergedById.putIfAbsent(f.id, () => f);
  }

  return AetherStats(
    totalScheduled: mergedById.length,
    activeFlights: activeFlights.value?.length ?? 0,
    totalReports: reports.length,
    longestDistance: longestDistance,
  );
});

/// Stats summary for Aether
class AetherStats {
  final int totalScheduled;
  final int activeFlights;
  final int totalReports;
  final double longestDistance;

  const AetherStats({
    required this.totalScheduled,
    required this.activeFlights,
    required this.totalReports,
    required this.longestDistance,
  });
}
