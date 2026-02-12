// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';

import '../models/sky_node.dart';
import '../services/sky_scanner_service.dart';

/// Provider for SkyScannerService
final skyScannerServiceProvider = Provider<SkyScannerService>((ref) {
  return SkyScannerService();
});

/// Provider for all sky nodes (upcoming and active)
final skyNodesProvider = StreamProvider<List<SkyNode>>((ref) {
  final service = ref.watch(skyScannerServiceProvider);
  return service.watchSkyNodes();
});

/// Provider for active flights only
final activeFlightsProvider = StreamProvider<List<SkyNode>>((ref) {
  final service = ref.watch(skyScannerServiceProvider);
  return service.watchActiveFlights();
});

/// Provider for user's own sky nodes
final userSkyNodesProvider = StreamProvider.family<List<SkyNode>, String>((
  ref,
  userId,
) {
  final service = ref.watch(skyScannerServiceProvider);
  return service.watchUserSkyNodes(userId);
});

/// Provider for reception reports for a specific sky node
final skyNodeReportsProvider =
    StreamProvider.family<List<ReceptionReport>, String>((ref, skyNodeId) {
      final service = ref.watch(skyScannerServiceProvider);
      return service.watchReports(skyNodeId);
    });

/// Provider for recent reception reports
final recentReportsProvider = StreamProvider<List<ReceptionReport>>((ref) {
  final service = ref.watch(skyScannerServiceProvider);
  return service.watchRecentReports();
});

/// Provider for global leaderboard — all-time top distances
///
/// This is the primary leaderboard, sorted by distance descending.
/// Data is persisted in Firestore and survives app deletion.
/// Accessible to all users globally.
final globalLeaderboardProvider = StreamProvider<List<ReceptionReport>>((ref) {
  final service = ref.watch(skyScannerServiceProvider);
  return service.watchLeaderboard();
});

/// Provider for this week's leaderboard
final weeklyLeaderboardProvider = StreamProvider<List<ReceptionReport>>((ref) {
  final service = ref.watch(skyScannerServiceProvider);
  final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
  return service.watchLeaderboardByPeriod(since: oneWeekAgo);
});

/// Provider for this month's leaderboard
final monthlyLeaderboardProvider = StreamProvider<List<ReceptionReport>>((ref) {
  final service = ref.watch(skyScannerServiceProvider);
  final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
  return service.watchLeaderboardByPeriod(since: oneMonthAgo);
});

/// Provider for the all-time distance record
final topDistanceRecordProvider = FutureProvider<ReceptionReport?>((ref) {
  final service = ref.watch(skyScannerServiceProvider);
  return service.getTopDistanceRecord();
});

/// Provider for a user's personal best distance
final userPersonalBestProvider =
    FutureProvider.family<ReceptionReport?, String>((ref, userId) {
      final service = ref.watch(skyScannerServiceProvider);
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
final flightPositionProvider = FutureProvider.autoDispose
    .family<FlightPositionState, String>((ref, callsign) async {
      final service = ref.watch(skyScannerServiceProvider);

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
        AppLogging.app('[SkyScanner] Error fetching position: $e');
        return FlightPositionState(isLoading: false, error: e.toString());
      }
    });

/// Provider to calculate distance from user to flight
final distanceToFlightProvider =
    Provider.family<double?, ({FlightPosition flight, double lat, double lon})>(
      (ref, params) {
        return SkyScannerService.calculateDistance(
          params.lat,
          params.lon,
          params.flight.latitude,
          params.flight.longitude,
        );
      },
    );

/// Stats provider for sky scanner
///
/// Uses the global leaderboard for accurate stats that persist
/// across app reinstalls and are consistent for all users.
final skyScannerStatsProvider = Provider<SkyScannerStats>((ref) {
  final skyNodes = ref.watch(skyNodesProvider);
  final activeFlights = ref.watch(activeFlightsProvider);
  final leaderboard = ref.watch(globalLeaderboardProvider);

  // Get total report count from leaderboard (all reports with distance)
  final reports = leaderboard.value ?? [];
  final longestDistance = reports.isNotEmpty
      ? reports.first.estimatedDistance ?? 0
      : 0.0;

  return SkyScannerStats(
    totalScheduled: skyNodes.value?.length ?? 0,
    activeFlights: activeFlights.value?.length ?? 0,
    totalReports: reports.length,
    longestDistance: longestDistance,
  );
});

/// Stats summary for sky scanner
class SkyScannerStats {
  final int totalScheduled;
  final int activeFlights;
  final int totalReports;
  final double longestDistance;

  const SkyScannerStats({
    required this.totalScheduled,
    required this.activeFlights,
    required this.totalReports,
    required this.longestDistance,
  });
}
