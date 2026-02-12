// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';

import '../models/aether_flight.dart';
import '../services/aether_service.dart';

/// Provider for AetherService
final aetherServiceProvider = Provider<AetherService>((ref) {
  return AetherService();
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

/// Provider for user's own flights
final aetherUserFlightsProvider =
    StreamProvider.family<List<AetherFlight>, String>((ref, userId) {
      final service = ref.watch(aetherServiceProvider);
      return service.watchUserFlights(userId);
    });

/// Provider for reception reports for a specific flight
final aetherFlightReportsProvider =
    StreamProvider.family<List<ReceptionReport>, String>((ref, flightId) {
      final service = ref.watch(aetherServiceProvider);
      return service.watchReports(flightId);
    });

/// Provider for recent reception reports
final aetherRecentReportsProvider = StreamProvider<List<ReceptionReport>>((
  ref,
) {
  final service = ref.watch(aetherServiceProvider);
  return service.watchRecentReports();
});

/// Provider for global leaderboard — all-time top distances
///
/// This is the primary leaderboard, sorted by distance descending.
/// Data is persisted in Firestore and survives app deletion.
/// Accessible to all users globally.
final aetherGlobalLeaderboardProvider = StreamProvider<List<ReceptionReport>>((
  ref,
) {
  final service = ref.watch(aetherServiceProvider);
  return service.watchLeaderboard();
});

/// Provider for this week's leaderboard
final aetherWeeklyLeaderboardProvider = StreamProvider<List<ReceptionReport>>((
  ref,
) {
  final service = ref.watch(aetherServiceProvider);
  final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
  return service.watchLeaderboardByPeriod(since: oneWeekAgo);
});

/// Provider for this month's leaderboard
final aetherMonthlyLeaderboardProvider = StreamProvider<List<ReceptionReport>>((
  ref,
) {
  final service = ref.watch(aetherServiceProvider);
  final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
  return service.watchLeaderboardByPeriod(since: oneMonthAgo);
});

/// Provider for the all-time distance record
final aetherTopDistanceRecordProvider = FutureProvider<ReceptionReport?>((ref) {
  final service = ref.watch(aetherServiceProvider);
  return service.getTopDistanceRecord();
});

/// Provider for a user's personal best distance
final aetherUserPersonalBestProvider =
    FutureProvider.family<ReceptionReport?, String>((ref, userId) {
      final service = ref.watch(aetherServiceProvider);
      return service.getUserPersonalBest(userId);
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

/// Provider for live flight position tracking using FutureProvider
/// Auto-refreshes periodically while watched
final aetherFlightPositionProvider = FutureProvider.autoDispose
    .family<FlightPositionState, String>((ref, callsign) async {
      final service = ref.watch(aetherServiceProvider);

      // Set up periodic refresh every 30 seconds
      final timer = Timer.periodic(const Duration(seconds: 30), (_) {
        ref.invalidateSelf();
      });
      ref.onDispose(timer.cancel);

      try {
        final position = await service.getFlightPosition(callsign);
        return FlightPositionState(
          position: position,
          isLoading: false,
          lastFetch: DateTime.now(),
        );
      } catch (e) {
        AppLogging.app('[Aether] Error fetching position: $e');
        return FlightPositionState(isLoading: false, error: e.toString());
      }
    });

/// Provider to calculate distance from user to flight
final aetherDistanceToFlightProvider =
    Provider.family<double?, ({FlightPosition flight, double lat, double lon})>(
      (ref, params) {
        return AetherService.calculateDistance(
          params.lat,
          params.lon,
          params.flight.latitude,
          params.flight.longitude,
        );
      },
    );

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

  return AetherStats(
    totalScheduled: flights.value?.length ?? 0,
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
