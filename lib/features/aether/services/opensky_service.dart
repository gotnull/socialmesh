// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:socialmesh/core/logging.dart';

/// OpenSky Network API service with OAuth2 authentication.
///
/// Provides flight validation and lookup using the OpenSky Network API.
/// Uses OAuth2 client credentials flow for authentication.
///
/// Rate limits:
/// - 4000 credits/day for authenticated users
/// - Credits vary by endpoint and query scope
///
/// API Documentation: https://openskynetwork.github.io/opensky-api/rest.html
class OpenSkyService {
  static const String _tokenUrl =
      'https://auth.opensky-network.org/auth/realms/opensky-network/protocol/openid-connect/token';
  static const String _apiBaseUrl = 'https://opensky-network.org/api';

  // OAuth2 credentials — loaded from .env, never hardcoded
  static String get _clientId =>
      dotenv.env['OPENSKY_CLIENT_ID'] ?? 'gotnull-api-client';
  static String get _clientSecret => dotenv.env['OPENSKY_CLIENT_SECRET'] ?? '';

  // Token cache
  String? _accessToken;
  DateTime? _tokenExpiry;

  // Rate limiting for search
  DateTime? _lastSearchTime;
  static const _searchCooldown = Duration(seconds: 5);

  // Singleton instance
  static final OpenSkyService _instance = OpenSkyService._internal();
  factory OpenSkyService() => _instance;
  OpenSkyService._internal();

  /// Get a valid access token, refreshing if necessary.
  Future<String?> _getAccessToken() async {
    // Check if we have a valid cached token (with 60s buffer)
    if (_accessToken != null && _tokenExpiry != null) {
      if (DateTime.now().isBefore(
        _tokenExpiry!.subtract(const Duration(seconds: 60)),
      )) {
        return _accessToken;
      }
    }

    AppLogging.aether('[OpenSky] Requesting new access token...');

    try {
      final response = await http
          .post(
            Uri.parse(_tokenUrl),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'grant_type': 'client_credentials',
              'client_id': _clientId,
              'client_secret': _clientSecret,
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _accessToken = json['access_token'] as String?;
        final expiresIn = json['expires_in'] as int? ?? 1800; // Default 30 min
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        AppLogging.aether('[OpenSky] Token obtained, expires in ${expiresIn}s');
        return _accessToken;
      } else {
        AppLogging.aether(
          '[OpenSky] Token request failed: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      AppLogging.aether('[OpenSky] Token request error: $e');
      return null;
    }
  }

  /// Make an authenticated API request.
  Future<http.Response?> _authenticatedGet(String endpoint) async {
    AppLogging.aether('[OpenSky] GET $endpoint');
    final token = await _getAccessToken();
    if (token == null) {
      AppLogging.aether('[OpenSky] No access token available');
      return null;
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_apiBaseUrl$endpoint'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      // Log rate limit info if available
      final remaining = response.headers['x-rate-limit-remaining'];
      if (remaining != null) {
        AppLogging.aether('[OpenSky] Credits remaining: $remaining');
      }

      return response;
    } catch (e) {
      AppLogging.aether('[OpenSky] API request error: $e');
      return null;
    }
  }

  /// Search for active flights matching a query string.
  ///
  /// Searches callsigns of all currently active flights.
  /// Returns up to [limit] matching flights sorted by relevance.
  /// Uses 4 credits (global states query).
  /// Rate limited to one search per 5 seconds.
  Future<List<ActiveFlightInfo>> searchActiveFlights(
    String query, {
    int limit = 20,
  }) async {
    AppLogging.aether(
      '[OpenSky] searchActiveFlights() — query="$query" limit=$limit',
    );
    if (query.trim().length < 2) {
      return [];
    }

    // Rate limiting - prevent abuse
    if (_lastSearchTime != null) {
      final elapsed = DateTime.now().difference(_lastSearchTime!);
      if (elapsed < _searchCooldown) {
        AppLogging.aether(
          '[OpenSky] Search rate limited, ${_searchCooldown.inSeconds - elapsed.inSeconds}s remaining',
        );
        return [];
      }
    }
    _lastSearchTime = DateTime.now();

    final response = await _authenticatedGet('/states/all');

    if (response == null || response.statusCode != 200) {
      return [];
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final states = json['states'] as List<dynamic>?;

      if (states == null || states.isEmpty) {
        return [];
      }

      final normalizedQuery = query.toUpperCase().trim();
      final results = <ActiveFlightInfo>[];

      for (final state in states) {
        if (state is! List || state.length < 8) continue;

        final callsign = (state[1] as String?)?.trim().toUpperCase() ?? '';
        if (callsign.isEmpty) continue;

        // Match if callsign starts with or contains the query
        if (callsign.startsWith(normalizedQuery) ||
            callsign.contains(normalizedQuery)) {
          final icao24 = state[0] as String?;
          final originCountry = state[2] as String?;
          final longitude = (state[5] as num?)?.toDouble();
          final latitude = (state[6] as num?)?.toDouble();
          final altitude = (state[7] as num?)?.toDouble();
          final onGround = state[8] as bool? ?? false;
          final velocity = (state[9] as num?)?.toDouble();

          results.add(
            ActiveFlightInfo(
              callsign: callsign,
              icao24: icao24,
              originCountry: originCountry,
              latitude: latitude,
              longitude: longitude,
              altitude: altitude,
              onGround: onGround,
              velocity: velocity,
            ),
          );

          if (results.length >= limit) break;
        }
      }

      // Sort by relevance - exact prefix matches first
      results.sort((a, b) {
        final aStartsWith = a.callsign.startsWith(normalizedQuery) ? 0 : 1;
        final bStartsWith = b.callsign.startsWith(normalizedQuery) ? 0 : 1;
        if (aStartsWith != bStartsWith) return aStartsWith - bStartsWith;
        return a.callsign.compareTo(b.callsign);
      });

      return results;
    } catch (e) {
      AppLogging.aether('[OpenSky] Search flights error: $e');
      return [];
    }
  }

  /// Check if a flight is currently active by callsign.
  ///
  /// Returns [FlightValidationResult] with flight status and position if found.
  /// Uses 1-4 credits depending on area (we use global search = 4 credits).
  Future<FlightValidationResult> validateFlightByCallsign(
    String callsign,
  ) async {
    AppLogging.aether(
      '[OpenSky] validateFlightByCallsign() — callsign="$callsign"',
    );
    final cleanCallsign = _normalizeCallsign(callsign);

    final response = await _authenticatedGet(
      '/states/all?callsign=$cleanCallsign',
    );

    if (response == null) {
      return FlightValidationResult(
        status: FlightValidationStatus.error,
        message: 'Unable to connect to OpenSky Network',
      );
    }

    if (response.statusCode == 429) {
      return FlightValidationResult(
        status: FlightValidationStatus.rateLimited,
        message: 'Rate limit exceeded. Try again later.',
      );
    }

    if (response.statusCode == 401) {
      // Token expired, clear cache and retry once
      _accessToken = null;
      _tokenExpiry = null;
      return FlightValidationResult(
        status: FlightValidationStatus.error,
        message: 'Authentication failed. Please try again.',
      );
    }

    if (response.statusCode != 200) {
      return FlightValidationResult(
        status: FlightValidationStatus.error,
        message: 'API error: ${response.statusCode}',
      );
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final states = json['states'] as List<dynamic>?;

      if (states == null || states.isEmpty) {
        return FlightValidationResult(
          status: FlightValidationStatus.notFound,
          message: 'Flight $cleanCallsign not currently in the air',
        );
      }

      // Parse the first matching state vector
      final state = states.first as List<dynamic>;
      final position = _parseStateVector(state, cleanCallsign);
      final icao24 = state[0] as String?;
      final originCountry = state[2] as String?;

      // Try to get route info (departure/arrival airports and times)
      // via the aircraft flights endpoint using the icao24 transponder ID.
      String? departureAirport;
      String? arrivalAirport;
      DateTime? departureTime;
      DateTime? arrivalTime;

      if (icao24 != null) {
        try {
          final routeInfo = await lookupAircraftRoute(icao24);
          if (routeInfo != null) {
            departureAirport = routeInfo.estDepartureAirport;
            arrivalAirport = routeInfo.estArrivalAirport;
            departureTime = routeInfo.departureTime;
            arrivalTime = routeInfo.arrivalTime;
          }
        } catch (e) {
          AppLogging.aether('[OpenSky] Route lookup failed (non-fatal): $e');
        }
      }

      return FlightValidationResult(
        status: FlightValidationStatus.active,
        message: 'Flight is currently active',
        position: position,
        icao24: icao24,
        originCountry: originCountry,
        departureAirport: departureAirport,
        arrivalAirport: arrivalAirport,
        departureTime: departureTime,
        arrivalTime: arrivalTime,
      );
    } catch (e) {
      AppLogging.aether('[OpenSky] Parse error: $e');
      return FlightValidationResult(
        status: FlightValidationStatus.error,
        message: 'Failed to parse flight data',
      );
    }
  }

  /// Get flights departing from an airport in a time range.
  ///
  /// [airport] must be an ICAO code (4 letters, e.g., KLAX, EDDF).
  /// Time range must not exceed 2 days.
  /// Uses credits based on time range (roughly 1 credit per day).
  Future<List<OpenSkyFlight>> getFlightsDeparting({
    required String airport,
    required DateTime begin,
    required DateTime end,
  }) async {
    AppLogging.aether(
      '[OpenSky] getFlightsDeparting() — airport=$airport '
      'begin=${begin.toIso8601String()} end=${end.toIso8601String()}',
    );
    final beginTs = begin.millisecondsSinceEpoch ~/ 1000;
    final endTs = end.millisecondsSinceEpoch ~/ 1000;

    final response = await _authenticatedGet(
      '/flights/departure?airport=${airport.toUpperCase()}&begin=$beginTs&end=$endTs',
    );

    if (response == null || response.statusCode != 200) {
      return [];
    }

    try {
      final json = jsonDecode(response.body) as List<dynamic>;
      return json
          .map((f) => OpenSkyFlight.fromJson(f as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogging.aether('[OpenSky] Parse departures error: $e');
      return [];
    }
  }

  /// Look up the current route for a specific aircraft by its ICAO24
  /// transponder address. Queries the last 2 hours of flight data.
  ///
  /// Returns the most recent [OpenSkyFlight] for the aircraft, or null
  /// if no route data is available (common for flights that just departed
  /// — OpenSky batch-processes route data with some delay).
  Future<OpenSkyFlight?> lookupAircraftRoute(String icao24) async {
    AppLogging.aether('[OpenSky] lookupAircraftRoute() — icao24=$icao24');
    final now = DateTime.now();
    // Extended window to 12 hours to catch flights that departed hours ago
    // Most commercial flights are under 12 hours, and we need the departure
    // data even for in-progress flights.
    final begin = now.subtract(const Duration(hours: 12));
    final beginTs = begin.millisecondsSinceEpoch ~/ 1000;
    final endTs = now.millisecondsSinceEpoch ~/ 1000;

    final response = await _authenticatedGet(
      '/flights/aircraft?icao24=${icao24.toLowerCase()}&begin=$beginTs&end=$endTs',
    );

    if (response == null || response.statusCode != 200) {
      return null;
    }

    try {
      final json = jsonDecode(response.body) as List<dynamic>;
      if (json.isEmpty) return null;

      // Return the most recent flight for this aircraft
      final flights = json
          .map((f) => OpenSkyFlight.fromJson(f as Map<String, dynamic>))
          .toList();

      // Sort by firstSeen descending so we get the latest
      flights.sort((a, b) => (b.firstSeen ?? 0).compareTo(a.firstSeen ?? 0));
      final flight = flights.first;

      // Log what data we got to help diagnose issues
      AppLogging.aether(
        '[OpenSky] Route found: dep=${flight.estDepartureAirport ?? "null"} '
        'arr=${flight.estArrivalAirport ?? "null"} '
        'firstSeen=${flight.firstSeen != null ? "${DateTime.fromMillisecondsSinceEpoch(flight.firstSeen! * 1000)}" : "null"} '
        'lastSeen=${flight.lastSeen != null ? "${DateTime.fromMillisecondsSinceEpoch(flight.lastSeen! * 1000)}" : "null"}',
      );

      return flight;
    } catch (e) {
      AppLogging.aether('[OpenSky] Aircraft route parse error: $e');
      return null;
    }
  }

  /// Validate a scheduled flight by checking departures from the airport.
  ///
  /// This is useful for validating flights that haven't departed yet.
  /// Note: OpenSky flight data is updated by batch process at night,
  /// so only flights from the previous day or earlier are available.
  Future<FlightValidationResult> validateScheduledFlight({
    required String flightNumber,
    required String departureAirport,
    required DateTime scheduledDeparture,
  }) async {
    AppLogging.aether(
      '[OpenSky] validateScheduledFlight() — $flightNumber from $departureAirport '
      'at ${scheduledDeparture.toIso8601String()}',
    );
    // First, try to check if it's currently active
    final activeResult = await validateFlightByCallsign(flightNumber);
    if (activeResult.status == FlightValidationStatus.active) {
      return activeResult;
    }

    // If not active and the flight is in the past, check historical data
    if (scheduledDeparture.isBefore(
      DateTime.now().subtract(const Duration(days: 1)),
    )) {
      // Convert IATA to ICAO if needed (basic US airport mapping)
      final icaoAirport = _iataToIcao(departureAirport);

      // Search a 6-hour window around the scheduled time
      final begin = scheduledDeparture.subtract(const Duration(hours: 3));
      final end = scheduledDeparture.add(const Duration(hours: 3));

      final departures = await getFlightsDeparting(
        airport: icaoAirport,
        begin: begin,
        end: end,
      );

      final normalizedCallsign = _normalizeCallsign(flightNumber);
      final matchingFlight = departures.where((f) {
        final flightCallsign = f.callsign?.trim().toUpperCase() ?? '';
        return flightCallsign.contains(normalizedCallsign) ||
            normalizedCallsign.contains(flightCallsign);
      }).firstOrNull;

      if (matchingFlight != null) {
        return FlightValidationResult(
          status: FlightValidationStatus.verified,
          message: 'Flight verified in historical data',
          icao24: matchingFlight.icao24,
          departureAirport: matchingFlight.estDepartureAirport,
          arrivalAirport: matchingFlight.estArrivalAirport,
          departureTime: matchingFlight.departureTime,
          arrivalTime: matchingFlight.arrivalTime,
        );
      }

      return FlightValidationResult(
        status: FlightValidationStatus.notFound,
        message: 'Flight not found in historical departures',
      );
    }

    // Future flight - can't validate yet
    return FlightValidationResult(
      status: FlightValidationStatus.pending,
      message: 'Flight is scheduled for the future. Will validate when active.',
    );
  }

  /// Normalize a flight number to OpenSky callsign format.
  ///
  /// Airlines use different callsign formats:
  /// - United: UA123 -> UAL123
  /// - Delta: DL456 -> DAL456
  /// - American: AA789 -> AAL789
  /// - Southwest: WN123 -> SWA123
  /// etc.
  String _normalizeCallsign(String flightNumber) {
    final upper = flightNumber.toUpperCase().trim().replaceAll(' ', '');

    // Common IATA to ICAO airline code mappings
    const iataToIcao = {
      'UA': 'UAL', // United
      'DL': 'DAL', // Delta
      'AA': 'AAL', // American
      'WN': 'SWA', // Southwest
      'B6': 'JBU', // JetBlue
      'AS': 'ASA', // Alaska
      'NK': 'NKS', // Spirit
      'F9': 'FFT', // Frontier
      'BA': 'BAW', // British Airways
      'LH': 'DLH', // Lufthansa
      'AF': 'AFR', // Air France
      'KL': 'KLM', // KLM
      'EK': 'UAE', // Emirates
      'QF': 'QFA', // Qantas
      'SQ': 'SIA', // Singapore Airlines
      'CX': 'CPA', // Cathay Pacific
      'NH': 'ANA', // ANA
      'JL': 'JAL', // Japan Airlines
      'KE': 'KAL', // Korean Air
      'AC': 'ACA', // Air Canada
      'QR': 'QTR', // Qatar Airways
      'TK': 'THY', // Turkish Airlines
      'LX': 'SWR', // Swiss
      'OS': 'AUA', // Austrian
      'SK': 'SAS', // SAS
      'AY': 'FIN', // Finnair
      'IB': 'IBE', // Iberia
      'AZ': 'ITY', // ITA Airways
      'VS': 'VIR', // Virgin Atlantic
      'VX': 'VRD', // Virgin America
      'HA': 'HAL', // Hawaiian
      'G4': 'AAY', // Allegiant
      '9W': 'JAI', // Jet Airways
      '3K': 'JSA', // Jetstar Asia
    };

    // Try to extract airline code and flight number
    final match = RegExp(r'^([A-Z0-9]{2,3})(\d+)([A-Z]?)$').firstMatch(upper);
    if (match != null) {
      final airlineCode = match.group(1)!;
      final flightNum = match.group(2)!;
      final suffix = match.group(3) ?? '';

      // Check if we have an ICAO mapping
      if (iataToIcao.containsKey(airlineCode)) {
        return '${iataToIcao[airlineCode]}$flightNum$suffix';
      }

      // If it's already 3 letters, assume it's ICAO
      if (airlineCode.length == 3) {
        return '$airlineCode$flightNum$suffix';
      }
    }

    // Return as-is if we can't parse it
    return upper;
  }

  /// Convert IATA airport code to ICAO.
  String _iataToIcao(String iata) {
    final upper = iata.toUpperCase().trim();

    // If already 4 letters, assume it's ICAO
    if (upper.length == 4) return upper;

    // Common US airports (K prefix)
    const usAirports = {
      'LAX': 'KLAX',
      'JFK': 'KJFK',
      'SFO': 'KSFO',
      'ORD': 'KORD',
      'DFW': 'KDFW',
      'DEN': 'KDEN',
      'ATL': 'KATL',
      'MIA': 'KMIA',
      'SEA': 'KSEA',
      'BOS': 'KBOS',
      'LAS': 'KLAS',
      'PHX': 'KPHX',
      'IAH': 'KIAH',
      'EWR': 'KEWR',
      'MSP': 'KMSP',
      'DTW': 'KDTW',
      'PHL': 'KPHL',
      'CLT': 'KCLT',
      'SLC': 'KSLC',
      'DCA': 'KDCA',
      'IAD': 'KIAD',
      'BWI': 'KBWI',
      'SAN': 'KSAN',
      'TPA': 'KTPA',
      'PDX': 'KPDX',
      'AUS': 'KAUS',
      'HNL': 'PHNL', // Hawaii uses P prefix
      'OGG': 'PHOG',
      'ANC': 'PANC', // Alaska uses P prefix
    };

    // International airports
    const intlAirports = {
      'LHR': 'EGLL', // London Heathrow
      'LGW': 'EGKK', // London Gatwick
      'CDG': 'LFPG', // Paris CDG
      'FRA': 'EDDF', // Frankfurt
      'AMS': 'EHAM', // Amsterdam
      'MAD': 'LEMD', // Madrid
      'BCN': 'LEBL', // Barcelona
      'FCO': 'LIRF', // Rome
      'MUC': 'EDDM', // Munich
      'ZRH': 'LSZH', // Zurich
      'VIE': 'LOWW', // Vienna
      'BRU': 'EBBR', // Brussels
      'CPH': 'EKCH', // Copenhagen
      'ARN': 'ESSA', // Stockholm
      'OSL': 'ENGM', // Oslo
      'HEL': 'EFHK', // Helsinki
      'DUB': 'EIDW', // Dublin
      'SIN': 'WSSS', // Singapore
      'HKG': 'VHHH', // Hong Kong
      'NRT': 'RJAA', // Tokyo Narita
      'HND': 'RJTT', // Tokyo Haneda
      'ICN': 'RKSI', // Seoul Incheon
      'PEK': 'ZBAA', // Beijing
      'PVG': 'ZSPD', // Shanghai Pudong
      'SYD': 'YSSY', // Sydney
      'MEL': 'YMML', // Melbourne
      'AKL': 'NZAA', // Auckland
      'DXB': 'OMDB', // Dubai
      'DOH': 'OTHH', // Doha
      'IST': 'LTFM', // Istanbul
      'JNB': 'FAOR', // Johannesburg
      'GRU': 'SBGR', // Sao Paulo
      'MEX': 'MMMX', // Mexico City
      'YYZ': 'CYYZ', // Toronto
      'YVR': 'CYVR', // Vancouver
      'YUL': 'CYUL', // Montreal
    };

    if (usAirports.containsKey(upper)) {
      return usAirports[upper]!;
    }

    if (intlAirports.containsKey(upper)) {
      return intlAirports[upper]!;
    }

    // Default: prepend K for potential US airport
    if (upper.length == 3) {
      return 'K$upper';
    }

    return upper;
  }

  /// Parse an OpenSky state vector into a FlightPosition.
  FlightPositionData? _parseStateVector(List<dynamic> state, String callsign) {
    try {
      return FlightPositionData(
        callsign: (state[1] as String?)?.trim() ?? callsign,
        icao24: state[0] as String?,
        originCountry: state[2] as String?,
        longitude: (state[5] as num?)?.toDouble(),
        latitude: (state[6] as num?)?.toDouble(),
        altitude: (state[7] as num?)?.toDouble(),
        onGround: state[8] as bool? ?? false,
        velocity: (state[9] as num?)?.toDouble(),
        heading: (state[10] as num?)?.toDouble(),
        verticalRate: (state[11] as num?)?.toDouble(),
        lastContact: state[4] != null
            ? DateTime.fromMillisecondsSinceEpoch((state[4] as int) * 1000)
            : null,
      );
    } catch (e) {
      AppLogging.aether('[OpenSky] Error parsing state vector: $e');
      return null;
    }
  }

  /// Clear the cached token (useful for testing or forced re-auth).
  void clearTokenCache() {
    AppLogging.aether('[OpenSky] Token cache cleared');
    _accessToken = null;
    _tokenExpiry = null;
  }
}

// =============================================================================
// Data Models
// =============================================================================

/// Status of flight validation.
enum FlightValidationStatus {
  /// Flight is currently active and tracked
  active,

  /// Flight was found in historical data
  verified,

  /// Flight not found in OpenSky data
  notFound,

  /// Flight is scheduled for the future
  pending,

  /// Rate limit exceeded
  rateLimited,

  /// API or network error
  error,
}

/// Result of flight validation.
class FlightValidationResult {
  final FlightValidationStatus status;
  final String message;
  final FlightPositionData? position;
  final String? icao24;
  final String? originCountry;
  final String? departureAirport;
  final String? arrivalAirport;
  final DateTime? departureTime;
  final DateTime? arrivalTime;

  const FlightValidationResult({
    required this.status,
    required this.message,
    this.position,
    this.icao24,
    this.originCountry,
    this.departureAirport,
    this.arrivalAirport,
    this.departureTime,
    this.arrivalTime,
  });

  bool get isValid =>
      status == FlightValidationStatus.active ||
      status == FlightValidationStatus.verified ||
      status == FlightValidationStatus.pending;

  bool get isActive => status == FlightValidationStatus.active;
}

/// Live flight position data from OpenSky.
class FlightPositionData {
  final String callsign;
  final String? icao24;
  final String? originCountry;
  final double? latitude;
  final double? longitude;
  final double? altitude;
  final bool onGround;
  final double? velocity;
  final double? heading;
  final double? verticalRate;
  final DateTime? lastContact;

  const FlightPositionData({
    required this.callsign,
    this.icao24,
    this.originCountry,
    this.latitude,
    this.longitude,
    this.altitude,
    this.onGround = false,
    this.velocity,
    this.heading,
    this.verticalRate,
    this.lastContact,
  });

  /// Altitude in feet.
  double? get altitudeFeet => altitude != null ? altitude! * 3.28084 : null;

  /// Velocity in knots.
  double? get velocityKnots => velocity != null ? velocity! * 1.94384 : null;

  /// Whether position data is available.
  bool get hasPosition => latitude != null && longitude != null;
}

/// Flight data from OpenSky /flights endpoints.
class OpenSkyFlight {
  final String? icao24;
  final int? firstSeen;
  final String? estDepartureAirport;
  final int? lastSeen;
  final String? estArrivalAirport;
  final String? callsign;
  final int? estDepartureAirportHorizDistance;
  final int? estDepartureAirportVertDistance;
  final int? estArrivalAirportHorizDistance;
  final int? estArrivalAirportVertDistance;
  final int? departureAirportCandidatesCount;
  final int? arrivalAirportCandidatesCount;

  const OpenSkyFlight({
    this.icao24,
    this.firstSeen,
    this.estDepartureAirport,
    this.lastSeen,
    this.estArrivalAirport,
    this.callsign,
    this.estDepartureAirportHorizDistance,
    this.estDepartureAirportVertDistance,
    this.estArrivalAirportHorizDistance,
    this.estArrivalAirportVertDistance,
    this.departureAirportCandidatesCount,
    this.arrivalAirportCandidatesCount,
  });

  factory OpenSkyFlight.fromJson(Map<String, dynamic> json) {
    return OpenSkyFlight(
      icao24: json['icao24'] as String?,
      firstSeen: json['firstSeen'] as int?,
      estDepartureAirport: json['estDepartureAirport'] as String?,
      lastSeen: json['lastSeen'] as int?,
      estArrivalAirport: json['estArrivalAirport'] as String?,
      callsign: json['callsign'] as String?,
      estDepartureAirportHorizDistance:
          json['estDepartureAirportHorizDistance'] as int?,
      estDepartureAirportVertDistance:
          json['estDepartureAirportVertDistance'] as int?,
      estArrivalAirportHorizDistance:
          json['estArrivalAirportHorizDistance'] as int?,
      estArrivalAirportVertDistance:
          json['estArrivalAirportVertDistance'] as int?,
      departureAirportCandidatesCount:
          json['departureAirportCandidatesCount'] as int?,
      arrivalAirportCandidatesCount:
          json['arrivalAirportCandidatesCount'] as int?,
    );
  }

  /// Get departure time as DateTime.
  DateTime? get departureTime => firstSeen != null
      ? DateTime.fromMillisecondsSinceEpoch(firstSeen! * 1000)
      : null;

  /// Get arrival time as DateTime.
  DateTime? get arrivalTime => lastSeen != null
      ? DateTime.fromMillisecondsSinceEpoch(lastSeen! * 1000)
      : null;
}

/// Active flight info from live search.
class ActiveFlightInfo {
  final String callsign;
  final String? icao24;
  final String? originCountry;
  final double? latitude;
  final double? longitude;
  final double? altitude;
  final bool onGround;
  final double? velocity;

  const ActiveFlightInfo({
    required this.callsign,
    this.icao24,
    this.originCountry,
    this.latitude,
    this.longitude,
    this.altitude,
    this.onGround = false,
    this.velocity,
  });

  /// Altitude in feet (converted from meters).
  double? get altitudeFeet => altitude != null ? altitude! * 3.28084 : null;

  /// Velocity in knots (converted from m/s).
  double? get velocityKnots => velocity != null ? velocity! * 1.94384 : null;

  /// Display string for the flight.
  String get displayString {
    final parts = <String>[callsign];
    if (originCountry != null) parts.add('($originCountry)');
    if (altitudeFeet != null && !onGround) {
      parts.add('${altitudeFeet!.toStringAsFixed(0)} ft');
    }
    if (onGround) parts.add('(on ground)');
    return parts.join(' ');
  }
}
