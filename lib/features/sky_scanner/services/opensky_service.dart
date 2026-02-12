// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

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

  // OAuth2 credentials
  static const String _clientId = 'gotnull-api-client';
  static const String _clientSecret = 'zic97k9aAHWWMxFHbj9ajUQSlxPFo1Py';

  // Token cache
  String? _accessToken;
  DateTime? _tokenExpiry;

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

        AppLogging.app('[OpenSky] Token obtained, expires in ${expiresIn}s');
        return _accessToken;
      } else {
        AppLogging.app(
          '[OpenSky] Token request failed: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      AppLogging.app('[OpenSky] Token request error: $e');
      return null;
    }
  }

  /// Make an authenticated API request.
  Future<http.Response?> _authenticatedGet(String endpoint) async {
    final token = await _getAccessToken();
    if (token == null) {
      AppLogging.app('[OpenSky] No access token available');
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
        AppLogging.app('[OpenSky] Credits remaining: $remaining');
      }

      return response;
    } catch (e) {
      AppLogging.app('[OpenSky] API request error: $e');
      return null;
    }
  }

  /// Check if a flight is currently active by callsign.
  ///
  /// Returns [FlightValidationResult] with flight status and position if found.
  /// Uses 1-4 credits depending on area (we use global search = 4 credits).
  Future<FlightValidationResult> validateFlightByCallsign(
    String callsign,
  ) async {
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

      return FlightValidationResult(
        status: FlightValidationStatus.active,
        message: 'Flight is currently active',
        position: position,
        icao24: state[0] as String?,
        originCountry: state[2] as String?,
      );
    } catch (e) {
      AppLogging.app('[OpenSky] Parse error: $e');
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
      AppLogging.app('[OpenSky] Parse departures error: $e');
      return [];
    }
  }

  /// Get flights arriving at an airport in a time range.
  ///
  /// [airport] must be an ICAO code (4 letters, e.g., KJFK, EGLL).
  /// Time range must not exceed 2 days.
  Future<List<OpenSkyFlight>> getFlightsArriving({
    required String airport,
    required DateTime begin,
    required DateTime end,
  }) async {
    final beginTs = begin.millisecondsSinceEpoch ~/ 1000;
    final endTs = end.millisecondsSinceEpoch ~/ 1000;

    final response = await _authenticatedGet(
      '/flights/arrival?airport=${airport.toUpperCase()}&begin=$beginTs&end=$endTs',
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
      AppLogging.app('[OpenSky] Parse arrivals error: $e');
      return [];
    }
  }

  /// Get all flights in a time interval (max 2 hours).
  ///
  /// Useful for checking if a specific flight existed in a time range.
  Future<List<OpenSkyFlight>> getFlightsInInterval({
    required DateTime begin,
    required DateTime end,
  }) async {
    final beginTs = begin.millisecondsSinceEpoch ~/ 1000;
    final endTs = end.millisecondsSinceEpoch ~/ 1000;

    final response = await _authenticatedGet(
      '/flights/all?begin=$beginTs&end=$endTs',
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
      AppLogging.app('[OpenSky] Parse flights error: $e');
      return [];
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
      AppLogging.app('[OpenSky] Error parsing state vector: $e');
      return null;
    }
  }

  /// Clear the cached token (useful for testing or forced re-auth).
  void clearTokenCache() {
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

  const FlightValidationResult({
    required this.status,
    required this.message,
    this.position,
    this.icao24,
    this.originCountry,
    this.departureAirport,
    this.arrivalAirport,
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
