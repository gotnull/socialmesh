// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../models/aether_flight.dart';

/// Result of sharing a flight to the Aether API.
class AetherShareResult {
  /// The unique share ID returned by the API (e.g., "ae_abc123def456").
  final String id;

  /// The public URL for the shared flight.
  final String url;

  const AetherShareResult({required this.id, required this.url});
}

/// Paginated result from the Aether API flights listing.
class AetherFlightsPage {
  final List<AetherFlight> flights;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const AetherFlightsPage({
    required this.flights,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
}

/// Aggregate statistics from the Aether API.
class AetherApiStats {
  final int totalFlights;
  final int activeFlights;
  final int uniqueDepartures;
  final int uniqueArrivals;
  final int uniqueFlightNumbers;
  final int totalReceptions;
  final int? maxAltitude;

  const AetherApiStats({
    required this.totalFlights,
    required this.activeFlights,
    required this.uniqueDepartures,
    required this.uniqueArrivals,
    required this.uniqueFlightNumbers,
    required this.totalReceptions,
    this.maxAltitude,
  });

  factory AetherApiStats.fromJson(Map<String, dynamic> json) {
    return AetherApiStats(
      totalFlights: json['total_flights'] as int? ?? 0,
      activeFlights: json['active_flights'] as int? ?? 0,
      uniqueDepartures: json['unique_departures'] as int? ?? 0,
      uniqueArrivals: json['unique_arrivals'] as int? ?? 0,
      uniqueFlightNumbers: json['unique_flight_numbers'] as int? ?? 0,
      totalReceptions: json['total_receptions'] as int? ?? 0,
      maxAltitude: json['max_altitude'] as int?,
    );
  }
}

/// Airport list from the Aether API for filter dropdowns.
class AetherAirports {
  final List<String> departures;
  final List<String> arrivals;

  const AetherAirports({required this.departures, required this.arrivals});
}

/// Sort options for the flights listing.
enum AetherSortOption {
  newest('newest'),
  oldest('oldest'),
  departure('departure'),
  receptions('receptions');

  final String apiValue;
  const AetherSortOption(this.apiValue);
}

/// A leaderboard entry from the Aether API.
class AetherLeaderboardEntry {
  final int rank;
  final String id;
  final String flightId;
  final String flightNumber;
  final String? receiverName;
  final String? receiverNodeId;
  final double? latitude;
  final double? longitude;
  final double? altitudeM;
  final double? snr;
  final double? rssi;
  final double estimatedDistanceKm;
  final String? departure;
  final String? arrival;
  final String? airline;
  final String? nodeName;
  final int? altitudeFt;
  final String? frequency;
  final String receivedAt;

  const AetherLeaderboardEntry({
    required this.rank,
    required this.id,
    required this.flightId,
    required this.flightNumber,
    this.receiverName,
    this.receiverNodeId,
    this.latitude,
    this.longitude,
    this.altitudeM,
    this.snr,
    this.rssi,
    required this.estimatedDistanceKm,
    this.departure,
    this.arrival,
    this.airline,
    this.nodeName,
    this.altitudeFt,
    this.frequency,
    required this.receivedAt,
  });

  factory AetherLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return AetherLeaderboardEntry(
      rank: json['rank'] as int,
      id: json['id'] as String,
      flightId: json['flight_id'] as String,
      flightNumber: json['flight_number'] as String,
      receiverName: json['receiver_name'] as String?,
      receiverNodeId: json['receiver_node_id'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      altitudeM: (json['altitude_m'] as num?)?.toDouble(),
      snr: (json['snr'] as num?)?.toDouble(),
      rssi: (json['rssi'] as num?)?.toDouble(),
      estimatedDistanceKm: (json['estimated_distance_km'] as num).toDouble(),
      departure: json['departure'] as String?,
      arrival: json['arrival'] as String?,
      airline: json['airline'] as String?,
      nodeName: json['node_name'] as String?,
      altitudeFt: json['altitude_ft'] as int?,
      frequency: json['frequency'] as String?,
      receivedAt: json['received_at'] as String,
    );
  }

  /// Convert to a [ReceptionReport] for use in existing leaderboard UI.
  ReceptionReport toReceptionReport() {
    return ReceptionReport(
      id: id,
      aetherFlightId: flightId,
      flightNumber: flightNumber,
      reporterId: receiverNodeId ?? 'api',
      reporterName: receiverName,
      reporterNodeId: receiverNodeId,
      latitude: latitude,
      longitude: longitude,
      altitude: altitudeM,
      snr: snr,
      rssi: rssi,
      estimatedDistance: estimatedDistanceKm,
      receivedAt: DateTime.tryParse(receivedAt) ?? DateTime.now(),
      createdAt: DateTime.tryParse(receivedAt) ?? DateTime.now(),
    );
  }
}

/// Service for sharing and discovering Aether flights via the public API.
///
/// The Aether API is a Railway-hosted Node.js service that stores shared
/// flight snapshots and serves them via aether.socialmesh.app.
///
/// This service handles both outbound sharing (POST) and inbound discovery
/// (GET) of community-shared flights.
class AetherShareService {
  static const Duration _requestTimeout = Duration(seconds: 15);

  /// Share a flight to the Aether API.
  ///
  /// Posts the flight data to the backend and returns the share ID and URL.
  /// Throws on network errors or API failures.
  Future<AetherShareResult> shareFlight(AetherFlight flight) async {
    final baseUrl = AppUrls.aetherApiUrl;
    final apiKey = AppUrls.aetherApiKey;
    final uri = Uri.parse('$baseUrl/api/flight');

    AppLogging.aether('=' * 60);
    AppLogging.aether('shareFlight() called');
    AppLogging.aether(
      'Flight: ${flight.flightNumber} ${flight.departure} -> ${flight.arrival}',
    );
    AppLogging.aether('Base URL: $baseUrl');
    AppLogging.aether('Full URI: $uri');
    AppLogging.aether('API Key present: ${apiKey.isNotEmpty}');
    if (apiKey.isNotEmpty) {
      AppLogging.aether('API Key (masked): ${apiKey.substring(0, 8)}...');
    }

    final headers = <String, String>{'Content-Type': 'application/json'};

    if (apiKey.isNotEmpty) {
      headers['X-API-Key'] = apiKey;
    }

    final body = _flightToSharePayload(flight);
    AppLogging.aether('Request payload: ${jsonEncode(body)}');
    AppLogging.aether('Request headers: $headers');

    AppLogging.aether('Sending POST request...');

    try {
      final response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(_requestTimeout);

      AppLogging.aether('Response received');
      AppLogging.aether('Status code: ${response.statusCode}');
      AppLogging.aether('Response headers: ${response.headers}');
      AppLogging.aether('Response body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final id = json['id'] as String;
        final url = json['url'] as String;

        AppLogging.aether('Flight shared successfully!');
        AppLogging.aether('Share ID: $id');
        AppLogging.aether('Share URL: $url');
        AppLogging.aether('=' * 60);
        return AetherShareResult(id: id, url: url);
      }

      final errorBody = response.body;
      AppLogging.aether('Share failed: HTTP ${response.statusCode}');
      AppLogging.aether('Error body: $errorBody');
      AppLogging.aether('=' * 60);
      throw AetherShareException(
        'Failed to share flight (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is AetherShareException) rethrow;
      AppLogging.aether('Share error (exception): $e');
      AppLogging.aether('Error type: ${e.runtimeType}');
      AppLogging.aether('=' * 60);
      throw AetherShareException('Network error: $e');
    }
  }

  /// Build the JSON payload for the Aether API from an [AetherFlight].
  Map<String, dynamic> _flightToSharePayload(AetherFlight flight) {
    return {
      'flight_number': flight.flightNumber.toUpperCase(),
      'departure': flight.departure.toUpperCase(),
      'arrival': flight.arrival.toUpperCase(),
      if (flight.airline != null) 'airline': flight.airline,
      if (flight.nodeId.isNotEmpty) 'node_id': flight.nodeId,
      if (flight.nodeName != null) 'node_name': flight.nodeName,
      if (flight.userName != null) 'user_name': flight.userName,
      if (flight.notes != null) 'notes': flight.notes,
      'scheduled_departure': flight.scheduledDeparture
          .toUtc()
          .toIso8601String(),
      if (flight.scheduledArrival != null)
        'scheduled_arrival': flight.scheduledArrival!.toUtc().toIso8601String(),
      'is_active': flight.isActive,
      'reception_count': flight.receptionCount,
    };
  }

  /// Generate the share URL for a flight that has already been shared.
  static String getShareUrl(String shareId) {
    return AppUrls.shareFlightUrl(shareId);
  }

  // ==========================================================================
  // Discovery (GET operations)
  // ==========================================================================

  /// Fetch a paginated list of community-shared flights.
  ///
  /// Supports full-text search via [query], airport filtering via
  /// [departure] and [arrival], status filtering via [activeOnly],
  /// sorting, and pagination.
  Future<AetherFlightsPage> fetchFlights({
    String? query,
    String? departure,
    String? arrival,
    String? flightNumber,
    bool? activeOnly,
    AetherSortOption sort = AetherSortOption.newest,
    int page = 1,
    int limit = 20,
  }) async {
    final baseUrl = AppUrls.aetherApiUrl;
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'sort': sort.apiValue,
    };

    if (query != null && query.isNotEmpty) params['q'] = query;
    if (departure != null && departure.isNotEmpty) {
      params['departure'] = departure;
    }
    if (arrival != null && arrival.isNotEmpty) params['arrival'] = arrival;
    if (flightNumber != null && flightNumber.isNotEmpty) {
      params['flight_number'] = flightNumber;
    }
    if (activeOnly != null) params['active'] = activeOnly.toString();

    final uri = Uri.parse(
      '$baseUrl/api/flights',
    ).replace(queryParameters: params);

    try {
      final response = await http.get(uri).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final flightsJson = json['flights'] as List<dynamic>;
        final pagination = json['pagination'] as Map<String, dynamic>;

        final flights = flightsJson
            .map((e) => AetherFlight.fromApiJson(e as Map<String, dynamic>))
            .toList();

        return AetherFlightsPage(
          flights: flights,
          page: pagination['page'] as int,
          limit: pagination['limit'] as int,
          total: pagination['total'] as int,
          totalPages: pagination['totalPages'] as int,
        );
      }

      AppLogging.aether('Fetch flights failed: HTTP ${response.statusCode}');
      throw AetherShareException(
        'Failed to fetch flights (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is AetherShareException) rethrow;
      AppLogging.aether('Fetch flights error: $e');
      throw AetherShareException('Network error: $e');
    }
  }

  /// Fetch a single flight by its share ID.
  Future<AetherFlight> fetchFlight(String id) async {
    final baseUrl = AppUrls.aetherApiUrl;
    final uri = Uri.parse('$baseUrl/api/flight/$id');

    AppLogging.aether('fetchFlight() called for ID: $id');
    AppLogging.aether('URI: $uri');

    try {
      final response = await http.get(uri).timeout(_requestTimeout);

      AppLogging.aether('Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        AppLogging.aether('Flight fetched successfully');
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return AetherFlight.fromApiJson(json);
      }

      if (response.statusCode == 404) {
        AppLogging.aether('Flight not found (404)');
        throw const AetherShareException('Flight not found', statusCode: 404);
      }

      AppLogging.aether('Fetch failed: ${response.statusCode}');
      throw AetherShareException(
        'Failed to fetch flight (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is AetherShareException) rethrow;
      AppLogging.aether('Fetch flight error: $e');
      throw AetherShareException('Network error: $e');
    }
  }

  /// Fetch aggregate statistics from the API.
  Future<AetherApiStats> fetchStats() async {
    final baseUrl = AppUrls.aetherApiUrl;
    final uri = Uri.parse('$baseUrl/api/flights/stats');

    try {
      final response = await http.get(uri).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return AetherApiStats.fromJson(json);
      }

      throw AetherShareException(
        'Failed to fetch stats (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is AetherShareException) rethrow;
      AppLogging.aether('Fetch stats error: $e');
      throw AetherShareException('Network error: $e');
    }
  }

  /// Fetch available airport codes for filter dropdowns.
  Future<AetherAirports> fetchAirports() async {
    final baseUrl = AppUrls.aetherApiUrl;
    final uri = Uri.parse('$baseUrl/api/flights/airports');

    try {
      final response = await http.get(uri).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final departures = (json['departures'] as List<dynamic>).cast<String>();
        final arrivals = (json['arrivals'] as List<dynamic>).cast<String>();
        return AetherAirports(departures: departures, arrivals: arrivals);
      }

      throw AetherShareException(
        'Failed to fetch airports (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is AetherShareException) rethrow;
      AppLogging.aether('Fetch airports error: $e');
      throw AetherShareException('Network error: $e');
    }
  }

  /// Check if the Aether API is reachable.
  Future<bool> checkHealth() async {
    try {
      final baseUrl = AppUrls.aetherApiUrl;
      final uri = Uri.parse('$baseUrl/health');
      final response = await http.get(uri).timeout(_requestTimeout);
      return response.statusCode == 200;
    } catch (e) {
      AppLogging.aether('Health check failed: $e');
      return false;
    }
  }

  /// Fetch the distance leaderboard from the API.
  ///
  /// Returns up to [limit] entries sorted by reception distance descending.
  Future<List<AetherLeaderboardEntry>> fetchLeaderboard({
    int limit = 50,
  }) async {
    final baseUrl = AppUrls.aetherApiUrl;
    final uri = Uri.parse('$baseUrl/api/leaderboard?limit=$limit');

    try {
      final response = await http.get(uri).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final entries = json['leaderboard'] as List<dynamic>;
        return entries
            .map(
              (e) => AetherLeaderboardEntry.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }

      AppLogging.aether(
        'Fetch leaderboard failed: HTTP ${response.statusCode}',
      );
      throw AetherShareException(
        'Failed to fetch leaderboard (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is AetherShareException) rethrow;
      AppLogging.aether('Fetch leaderboard error: $e');
      throw AetherShareException('Network error: $e');
    }
  }
}

/// Exception thrown when sharing a flight fails.
class AetherShareException implements Exception {
  final String message;
  final int? statusCode;

  const AetherShareException(this.message, {this.statusCode});

  @override
  String toString() => 'AetherShareException: $message';
}
