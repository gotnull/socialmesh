// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';

import '../models/aether_flight.dart';
import '../services/aether_service.dart';
import '../services/aether_share_service.dart';
import '../services/opensky_service.dart';

/// Provider for AetherService
final aetherServiceProvider = Provider<AetherService>((ref) {
  return AetherService();
});

/// Provider for AetherShareService (sharing flights to aether.socialmesh.app)
final aetherShareServiceProvider = Provider<AetherShareService>((ref) {
  return AetherShareService();
});

/// Provider for OpenSkyService (authenticated flight lookups)
final openSkyServiceProvider = Provider<OpenSkyService>((ref) {
  return OpenSkyService();
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

/// Provider for live flight position tracking using FutureProvider
/// Auto-refreshes periodically while watched.
/// Uses authenticated OpenSky API for better rate limits.
final aetherFlightPositionProvider = FutureProvider.autoDispose
    .family<FlightPositionState, String>((ref, callsign) async {
      AppLogging.aether('aetherFlightPositionProvider — tracking $callsign');
      final openSky = ref.watch(openSkyServiceProvider);

      // Set up periodic refresh every 30 seconds
      final timer = Timer.periodic(const Duration(seconds: 30), (_) {
        ref.invalidateSelf();
      });
      ref.onDispose(timer.cancel);

      try {
        final result = await openSky.validateFlightByCallsign(callsign);

        if (result.isActive && result.position != null) {
          final pos = result.position!;
          AppLogging.aether(
            'Position update for $callsign: '
            'lat=${pos.latitude} lon=${pos.longitude} alt=${pos.altitude}m',
          );
          return FlightPositionState(
            position: FlightPosition(
              callsign: pos.callsign,
              latitude: pos.latitude ?? 0,
              longitude: pos.longitude ?? 0,
              altitude: pos.altitude ?? 0,
              onGround: pos.onGround,
              velocity: pos.velocity ?? 0,
              heading: pos.heading ?? 0,
              lastUpdate: pos.lastContact ?? DateTime.now(),
            ),
            isLoading: false,
            lastFetch: DateTime.now(),
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

// =============================================================================
// Discovery Providers (Aether API)
// =============================================================================

/// Sentinel value for copyWith methods that need to distinguish
/// "not provided" from "explicitly set to null".
const Object _sentinel = Object();

/// Immutable state for the discovery feed.
@immutable
class DiscoveryState {
  final List<AetherFlight> flights;
  final int currentPage;
  final int totalPages;
  final int total;
  final bool isLoadingMore;
  final String? error;
  final String searchQuery;
  final String? departureFilter;
  final String? arrivalFilter;
  final bool? activeOnly;
  final AetherSortOption sort;

  const DiscoveryState({
    this.flights = const [],
    this.currentPage = 0,
    this.totalPages = 0,
    this.total = 0,
    this.isLoadingMore = false,
    this.error,
    this.searchQuery = '',
    this.departureFilter,
    this.arrivalFilter,
    this.activeOnly,
    this.sort = AetherSortOption.newest,
  });

  bool get hasMore => currentPage < totalPages;

  DiscoveryState copyWith({
    List<AetherFlight>? flights,
    int? currentPage,
    int? totalPages,
    int? total,
    bool? isLoadingMore,
    Object? error = _sentinel,
    String? searchQuery,
    Object? departureFilter = _sentinel,
    Object? arrivalFilter = _sentinel,
    Object? activeOnly = _sentinel,
    AetherSortOption? sort,
  }) {
    return DiscoveryState(
      flights: flights ?? this.flights,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error == _sentinel ? this.error : error as String?,
      searchQuery: searchQuery ?? this.searchQuery,
      departureFilter: departureFilter == _sentinel
          ? this.departureFilter
          : departureFilter as String?,
      arrivalFilter: arrivalFilter == _sentinel
          ? this.arrivalFilter
          : arrivalFilter as String?,
      activeOnly: activeOnly == _sentinel
          ? this.activeOnly
          : activeOnly as bool?,
      sort: sort ?? this.sort,
    );
  }
}

/// Notifier that manages paginated discovery state from the Aether API.
class DiscoveryNotifier extends AsyncNotifier<DiscoveryState> {
  static const int _pageSize = 20;

  @override
  Future<DiscoveryState> build() async {
    AppLogging.aether('DiscoveryNotifier.build() — initial fetch');
    return _fetchPage(1, const DiscoveryState());
  }

  Future<DiscoveryState> _fetchPage(int page, DiscoveryState current) async {
    AppLogging.aether(
      'DiscoveryNotifier._fetchPage() — page=$page '
      'query="${current.searchQuery}" dep=${current.departureFilter} '
      'arr=${current.arrivalFilter} active=${current.activeOnly} '
      'sort=${current.sort.apiValue}',
    );
    final service = ref.read(aetherShareServiceProvider);

    try {
      final result = await service.fetchFlights(
        query: current.searchQuery.isNotEmpty ? current.searchQuery : null,
        departure: current.departureFilter,
        arrival: current.arrivalFilter,
        activeOnly: current.activeOnly,
        sort: current.sort,
        page: page,
        limit: _pageSize,
      );

      final updatedFlights = page == 1
          ? result.flights
          : [...current.flights, ...result.flights];

      return current.copyWith(
        flights: updatedFlights,
        currentPage: result.page,
        totalPages: result.totalPages,
        total: result.total,
        isLoadingMore: false,
        error: null,
      );
    } catch (e) {
      AppLogging.aether('Discovery fetch error: $e');
      return current.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Load the next page of results (append).
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    AppLogging.aether(
      'DiscoveryNotifier.loadMore() — page ${current.currentPage + 1}',
    );

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final updated = await _fetchPage(current.currentPage + 1, current);
    state = AsyncData(updated);
  }

  /// Apply new search query and reload from page 1.
  Future<void> search(String query) async {
    final current = state.value ?? const DiscoveryState();
    if (current.searchQuery == query) return;
    AppLogging.aether('DiscoveryNotifier.search() — query="$query"');

    state = const AsyncLoading();
    final updated = await _fetchPage(1, current.copyWith(searchQuery: query));
    state = AsyncData(updated);
  }

  /// Apply airport departure filter and reload.
  Future<void> filterByDeparture(String? airport) async {
    AppLogging.aether(
      'DiscoveryNotifier.filterByDeparture() — airport=$airport',
    );
    final current = state.value ?? const DiscoveryState();
    state = const AsyncLoading();
    final updated = await _fetchPage(
      1,
      DiscoveryState(
        searchQuery: current.searchQuery,
        departureFilter: airport,
        arrivalFilter: current.arrivalFilter,
        activeOnly: current.activeOnly,
        sort: current.sort,
      ),
    );
    state = AsyncData(updated);
  }

  /// Apply airport arrival filter and reload.
  Future<void> filterByArrival(String? airport) async {
    AppLogging.aether('DiscoveryNotifier.filterByArrival() — airport=$airport');
    final current = state.value ?? const DiscoveryState();
    state = const AsyncLoading();
    final updated = await _fetchPage(
      1,
      DiscoveryState(
        searchQuery: current.searchQuery,
        departureFilter: current.departureFilter,
        arrivalFilter: airport,
        activeOnly: current.activeOnly,
        sort: current.sort,
      ),
    );
    state = AsyncData(updated);
  }

  /// Filter by active status (null = all, true = active, false = inactive).
  Future<void> filterByActive(bool? active) async {
    AppLogging.aether('DiscoveryNotifier.filterByActive() — active=$active');
    final current = state.value ?? const DiscoveryState();
    state = const AsyncLoading();
    final updated = await _fetchPage(
      1,
      DiscoveryState(
        searchQuery: current.searchQuery,
        departureFilter: current.departureFilter,
        arrivalFilter: current.arrivalFilter,
        activeOnly: active,
        sort: current.sort,
      ),
    );
    state = AsyncData(updated);
  }

  /// Change sort order and reload.
  Future<void> setSort(AetherSortOption sort) async {
    final current = state.value ?? const DiscoveryState();
    if (current.sort == sort) return;
    AppLogging.aether('DiscoveryNotifier.setSort() — sort=${sort.apiValue}');

    state = const AsyncLoading();
    final updated = await _fetchPage(
      1,
      DiscoveryState(
        searchQuery: current.searchQuery,
        departureFilter: current.departureFilter,
        arrivalFilter: current.arrivalFilter,
        activeOnly: current.activeOnly,
        sort: sort,
      ),
    );
    state = AsyncData(updated);
  }

  /// Refresh from page 1, preserving current filters.
  Future<void> refresh() async {
    AppLogging.aether('DiscoveryNotifier.refresh()');
    final current = state.value ?? const DiscoveryState();
    state = const AsyncLoading();
    final updated = await _fetchPage(
      1,
      DiscoveryState(
        searchQuery: current.searchQuery,
        departureFilter: current.departureFilter,
        arrivalFilter: current.arrivalFilter,
        activeOnly: current.activeOnly,
        sort: current.sort,
      ),
    );
    state = AsyncData(updated);
  }

  /// Clear all filters and reload.
  Future<void> clearFilters() async {
    AppLogging.aether('DiscoveryNotifier.clearFilters()');
    state = const AsyncLoading();
    final updated = await _fetchPage(1, const DiscoveryState());
    state = AsyncData(updated);
  }
}

/// Provider for the discovery feed (community-shared flights from the API).
final aetherDiscoveryProvider =
    AsyncNotifierProvider<DiscoveryNotifier, DiscoveryState>(
      DiscoveryNotifier.new,
    );

/// Provider for aggregate stats from the Aether API.
final aetherApiStatsProvider = FutureProvider<AetherApiStats>((ref) async {
  final service = ref.watch(aetherShareServiceProvider);
  return service.fetchStats();
});

/// Provider for available airport codes (for filter dropdowns).
final aetherApiAirportsProvider = FutureProvider<AetherAirports>((ref) async {
  final service = ref.watch(aetherShareServiceProvider);
  return service.fetchAirports();
});
