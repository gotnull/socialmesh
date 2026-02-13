// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../services/opensky_service.dart';

/// Bottom sheet for searching and selecting active flights from OpenSky.
class FlightSearchSheet extends StatefulWidget {
  const FlightSearchSheet({super.key});

  /// Show the flight search sheet and return the selected flight.
  static Future<ActiveFlightInfo?> show(
    BuildContext context, {
    bool isDismissible = true,
  }) {
    return AppBottomSheet.show<ActiveFlightInfo>(
      context: context,
      padding: EdgeInsets.zero,
      isDismissible: isDismissible,
      child: const FlightSearchSheet(),
    );
  }

  @override
  State<FlightSearchSheet> createState() => _FlightSearchSheetState();
}

class _FlightSearchSheetState extends State<FlightSearchSheet> {
  final _searchController = TextEditingController();
  final _openSky = OpenSkyService();

  List<ActiveFlightInfo> _results = [];
  bool _isLoading = false;
  String? _error;
  Timer? _debounce;
  bool _hasSearched = false;

  /// Cached route data keyed by icao24 transponder address.
  /// null value means lookup is in progress; populated once resolved.
  final Map<String, OpenSkyFlight?> _routeCache = {};

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });

    // Mark that user has started searching
    if (!_hasSearched && query.trim().length >= 2) {
      setState(() {
        _hasSearched = true;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _openSky.searchActiveFlights(query, limit: 30);

      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
          _error = results.isEmpty ? 'No active flights found' : null;
        });

        // Fetch route data for the top results in the background.
        // Limit to first 10 to avoid burning API credits.
        _fetchRoutesForResults(results.take(10).toList());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _isLoading = false;
          _error = 'Search failed. Please try again.';
        });
      }
    }
  }

  void _selectFlight(ActiveFlightInfo flight) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(flight);
  }

  /// Fetch route info for search results in parallel (max 3 concurrent).
  /// Updates the UI as each route resolves so tiles enrich progressively.
  Future<void> _fetchRoutesForResults(List<ActiveFlightInfo> flights) async {
    final toFetch = flights
        .where((f) => f.icao24 != null && !_routeCache.containsKey(f.icao24))
        .toList();

    if (toFetch.isEmpty) return;

    // Mark as in-progress (null = loading)
    for (final f in toFetch) {
      _routeCache[f.icao24!] = null;
    }

    // Process in batches of 3 to avoid hammering the API
    const batchSize = 3;
    for (var i = 0; i < toFetch.length; i += batchSize) {
      if (!mounted) return;

      final batch = toFetch.skip(i).take(batchSize);
      final futures = batch.map((f) async {
        try {
          final route = await _openSky.lookupAircraftRoute(f.icao24!);
          if (mounted) {
            setState(() {
              _routeCache[f.icao24!] = route;
            });
          }
        } catch (_) {
          // Non-fatal — tile just won't show route info
        }
      });

      await Future.wait(futures);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fixed height: 70% of screen. No resizing, no janky layout shifts.
    final sheetHeight = MediaQuery.of(context).size.height * 0.7;

    // Prevent dismissal during active search to avoid wasted API calls
    return PopScope(
      canPop: !_isLoading,
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Search Active Flights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                maxLength: 11,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Flight number (e.g. UA123)',
                  hintStyle: TextStyle(
                    color: context.textTertiary,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.flight_takeoff,
                    color: context.textTertiary,
                    size: 20,
                  ),
                  suffixIcon: _isLoading
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.accentColor,
                            ),
                          ),
                        )
                      : _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: context.textTertiary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _results = [];
                              _error = null;
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: context.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                  counterStyle: TextStyle(color: context.textTertiary),
                ),
                onChanged: _onSearchChanged,
              ),
            ),

            Divider(height: 1, color: context.border),

            // Results — always fills remaining space, no resizing
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_searchController.text.trim().length < 2) {
      return _buildHint();
    }

    if (_error != null && _results.isEmpty) {
      return _buildError();
    }

    if (_results.isEmpty && !_isLoading) {
      return _buildEmpty();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final flight = _results[index];
        final route = flight.icao24 != null ? _routeCache[flight.icao24] : null;
        return _FlightResultTile(
          flight: flight,
          route: route,
          onTap: () => _selectFlight(flight),
        );
      },
    );
  }

  Widget _buildHint() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flight,
              size: 48,
              color: context.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Search for active flights',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter at least 2 characters to search\nfor flights currently in the air',
              style: TextStyle(color: context.textTertiary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: context.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No active flights found',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different flight number or check\nif the flight is currently airborne',
              style: TextStyle(color: context.textTertiary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _performSearch(_searchController.text),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlightResultTile extends StatelessWidget {
  final ActiveFlightInfo flight;
  final OpenSkyFlight? route;
  final VoidCallback onTap;

  const _FlightResultTile({
    required this.flight,
    this.route,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasRoute =
        route != null &&
        (route!.estDepartureAirport != null ||
            route!.estArrivalAirport != null);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      color: context.background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Flight icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  flight.onGround ? Icons.flight_land : Icons.flight_takeoff,
                  color: context.accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Flight info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Callsign + country
                    Row(
                      children: [
                        Text(
                          flight.callsign,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (flight.originCountry != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            flight.originCountry!,
                            style: TextStyle(
                              color: context.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Route: DEP -> ARR
                    if (hasRoute) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.route,
                            size: 13,
                            color: context.accentColor.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _buildRouteString(),
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 2),

                    // Speed + departure time
                    Text(
                      _buildSubtitle(),
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Altitude badge
              if (!flight.onGround && flight.altitudeFeet != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${NumberFormat('#,##0').format(flight.altitudeFeet!.round())} ft',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  String _buildRouteString() {
    final dep = route?.estDepartureAirport ?? '???';
    final arr = route?.estArrivalAirport ?? '???';
    return '$dep \u2192 $arr';
  }

  String _buildSubtitle() {
    final parts = <String>[];

    if (flight.onGround) {
      parts.add('On ground');
    } else if (flight.velocityKnots != null) {
      parts.add(
        '${NumberFormat('#,##0').format(flight.velocityKnots!.round())} kts',
      );
    }

    // Show departure time if route data available
    if (route?.departureTime != null) {
      final fmt = DateFormat('h:mm a');
      parts.add('Departed ${fmt.format(route!.departureTime!)}');
    }

    return parts.isEmpty ? 'Active flight' : parts.join(' \u00B7 ');
  }
}
