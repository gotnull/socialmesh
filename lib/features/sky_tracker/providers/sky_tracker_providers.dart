// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';

import '../models/sky_node.dart';
import '../services/sky_tracker_service.dart';

/// Provider for SkyTrackerService
final skyTrackerServiceProvider = Provider<SkyTrackerService>((ref) {
  return SkyTrackerService();
});

/// Provider for all sky nodes (upcoming and active)
final skyNodesProvider = StreamProvider<List<SkyNode>>((ref) {
  final service = ref.watch(skyTrackerServiceProvider);
  return service.watchSkyNodes();
});

/// Provider for active flights only
final activeFlightsProvider = StreamProvider<List<SkyNode>>((ref) {
  final service = ref.watch(skyTrackerServiceProvider);
  return service.watchActiveFlights();
});

/// Provider for user's own sky nodes
final userSkyNodesProvider = StreamProvider.family<List<SkyNode>, String>((
  ref,
  userId,
) {
  final service = ref.watch(skyTrackerServiceProvider);
  return service.watchUserSkyNodes(userId);
});

/// Provider for reception reports for a specific sky node
final skyNodeReportsProvider =
    StreamProvider.family<List<ReceptionReport>, String>((ref, skyNodeId) {
      final service = ref.watch(skyTrackerServiceProvider);
      return service.watchReports(skyNodeId);
    });

/// Provider for recent reception reports (leaderboard)
final recentReportsProvider = StreamProvider<List<ReceptionReport>>((ref) {
  final service = ref.watch(skyTrackerServiceProvider);
  return service.watchRecentReports();
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
      final service = ref.watch(skyTrackerServiceProvider);

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
        AppLogging.app('[SkyTracker] Error fetching position: $e');
        return FlightPositionState(isLoading: false, error: e.toString());
      }
    });

/// Provider to calculate distance from user to flight
final distanceToFlightProvider =
    Provider.family<double?, ({FlightPosition flight, double lat, double lon})>(
      (ref, params) {
        return SkyTrackerService.calculateDistance(
          params.lat,
          params.lon,
          params.flight.latitude,
          params.flight.longitude,
        );
      },
    );

/// Stats provider for sky tracker
final skyTrackerStatsProvider = Provider<SkyTrackerStats>((ref) {
  final skyNodes = ref.watch(skyNodesProvider);
  final activeFlights = ref.watch(activeFlightsProvider);
  final reports = ref.watch(recentReportsProvider);

  return SkyTrackerStats(
    totalScheduled: skyNodes.value?.length ?? 0,
    activeFlights: activeFlights.value?.length ?? 0,
    totalReports: reports.value?.length ?? 0,
    longestDistance:
        reports.value
            ?.where((r) => r.estimatedDistance != null)
            .map((r) => r.estimatedDistance!)
            .fold<double>(0, (max, d) => d > max ? d : max) ??
        0,
  );
});

/// Stats summary for sky tracker
class SkyTrackerStats {
  final int totalScheduled;
  final int activeFlights;
  final int totalReports;
  final double longestDistance;

  const SkyTrackerStats({
    required this.totalScheduled,
    required this.activeFlights,
    required this.totalReports,
    required this.longestDistance,
  });
}
