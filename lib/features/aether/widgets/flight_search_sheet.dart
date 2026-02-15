// SPDX-License-Identifier: GPL-3.0-or-later

// Flight Search Screen — search OpenSky for active flights.
//
// Full-screen route (same pattern as UserSearchScreen / SignalFeedScreen).
// Single debounced search path — no duplicate calls, no race conditions.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/info_chip.dart';
import '../services/opensky_service.dart';

// =============================================================================
// Screen
// =============================================================================

/// Full-screen flight search. Returns a selected [ActiveFlightInfo] or null.
class FlightSearchSheet extends StatefulWidget {
  const FlightSearchSheet({super.key});

  static Future<ActiveFlightInfo?> show(BuildContext context) {
    return Navigator.of(context).push<ActiveFlightInfo>(
      MaterialPageRoute(builder: (_) => const FlightSearchSheet()),
    );
  }

  @override
  State<FlightSearchSheet> createState() => _FlightSearchSheetState();
}

// =============================================================================
// Search state machine
// =============================================================================

enum _SearchState { idle, loading, results, empty, error }

class _FlightSearchSheetState extends State<FlightSearchSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _openSky = OpenSkyService();
  final Map<String, OpenSkyFlight?> _routeCache = {};

  Timer? _debounce;
  _SearchState _state = _SearchState.idle;
  List<ActiveFlightInfo> _results = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Search logic — single entry point, debounced
  // ---------------------------------------------------------------------------

  void _onTextChanged(String text) {
    _debounce?.cancel();

    final query = text.trim().toUpperCase();
    if (query.length < 2) {
      setState(() {
        _state = _SearchState.idle;
        _results = [];
      });
      return;
    }

    // Show loading immediately so user sees feedback
    setState(() => _state = _SearchState.loading);

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    AppLogging.aether('FlightSearch: searching "$query"');

    try {
      final results = await _openSky.searchActiveFlights(query, limit: 30);
      if (!mounted) return;

      if (results.isEmpty) {
        setState(() {
          _state = _SearchState.empty;
          _results = [];
        });
      } else {
        setState(() {
          _state = _SearchState.results;
          _results = results;
        });
        _fetchRoutes(results.take(10).toList());
      }
    } catch (e) {
      if (!mounted) return;
      AppLogging.aether('FlightSearch: error — $e');
      setState(() {
        _state = _SearchState.error;
        _results = [];
        _errorMessage = 'Search failed. Please try again.';
      });
    }
  }

  void _clearSearch() {
    _controller.clear();
    _debounce?.cancel();
    setState(() {
      _state = _SearchState.idle;
      _results = [];
    });
    _focus.requestFocus();
  }

  void _selectFlight(ActiveFlightInfo flight) {
    AppLogging.aether('FlightSearch: selected ${flight.callsign}');
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(flight);
  }

  // ---------------------------------------------------------------------------
  // Route enrichment (background, non-blocking)
  // ---------------------------------------------------------------------------

  Future<void> _fetchRoutes(List<ActiveFlightInfo> flights) async {
    final toFetch = flights
        .where((f) => f.icao24 != null && !_routeCache.containsKey(f.icao24))
        .toList();
    if (toFetch.isEmpty) return;

    for (final f in toFetch) {
      _routeCache[f.icao24!] = null;
    }

    const batchSize = 3;
    for (var i = 0; i < toFetch.length; i += batchSize) {
      if (!mounted) return;
      final batch = toFetch.skip(i).take(batchSize);
      await Future.wait(
        batch.map((f) async {
          try {
            final route = await _openSky.lookupAircraftRoute(f.icao24!);
            if (mounted) setState(() => _routeCache[f.icao24!] = route);
          } catch (_) {}
        }),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: GlassScaffold(
        title: 'Search Flights',
        slivers: [
          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  onChanged: _onTextChanged,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  maxLength: 11,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Flight number (e.g. UA123)',
                    hintStyle: TextStyle(color: context.textTertiary),
                    prefixIcon: Icon(
                      Icons.flight_takeoff,
                      color: context.textTertiary,
                    ),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: context.textTertiary,
                            ),
                            onPressed: _clearSearch,
                          )
                        : null,
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Divider
          SliverToBoxAdapter(
            child: Container(
              height: 1,
              color: context.border.withValues(alpha: 0.3),
            ),
          ),

          // Content — driven entirely by _state enum
          ..._buildContent(),
        ],
      ),
    );
  }

  List<Widget> _buildContent() {
    return switch (_state) {
      _SearchState.idle => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _CenteredMessage(
            icon: Icons.flight,
            title: 'Search for active flights',
            subtitle:
                'Enter at least 2 characters to search\nfor flights currently in the air',
          ),
        ),
      ],
      _SearchState.loading => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(color: context.accentColor),
          ),
        ),
      ],
      _SearchState.empty => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _CenteredMessage(
            icon: Icons.search_off,
            title: 'No active flights found',
            subtitle:
                'Try a different flight number or check\nif the flight is currently airborne',
          ),
        ),
      ],
      _SearchState.error => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
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
                    _errorMessage,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () =>
                        _executeSearch(_controller.text.trim().toUpperCase()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      _SearchState.results => [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          sliver: SliverList.builder(
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final flight = _results[index];
              final route = flight.icao24 != null
                  ? _routeCache[flight.icao24]
                  : null;
              return _FlightTile(
                flight: flight,
                route: route,
                onTap: () => _selectFlight(flight),
              );
            },
          ),
        ),
      ],
    };
  }
}

// =============================================================================
// Centered message widget (idle / empty states)
// =============================================================================

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: context.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: context.textTertiary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Flight result tile
// =============================================================================

class _FlightTile extends StatelessWidget {
  final ActiveFlightInfo flight;
  final OpenSkyFlight? route;
  final VoidCallback onTap;

  const _FlightTile({required this.flight, this.route, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasRoute =
        route != null &&
        (route!.estDepartureAirport != null ||
            route!.estArrivalAirport != null);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      color: context.card,
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
              // Icon
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

              // Info — vertical stack, no truncation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Callsign — own row, full width
                    Text(
                      flight.callsign,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),

                    // Route — own row
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
                          Flexible(
                            child: Text(
                              _routeString,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Metadata chips — wrapping, never truncated
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _buildChips(context),
                    ),
                  ],
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

  List<Widget> _buildChips(BuildContext context) {
    final chips = <Widget>[];

    // Country
    if (flight.originCountry != null) {
      chips.add(InfoChip(icon: Icons.public, label: flight.originCountry!));
    }

    // Altitude
    if (!flight.onGround && flight.altitudeFeet != null) {
      chips.add(
        InfoChip(
          icon: Icons.height,
          label:
              '${NumberFormat('#,##0').format(flight.altitudeFeet!.round())} ft',
        ),
      );
    }

    // Speed or on-ground
    if (flight.onGround) {
      chips.add(InfoChip(icon: Icons.flight_land, label: 'On ground'));
    } else if (flight.velocityKnots != null) {
      chips.add(
        InfoChip(
          icon: Icons.speed,
          label:
              '${NumberFormat('#,##0').format(flight.velocityKnots!.round())} kts',
        ),
      );
    }

    // Departure time
    if (route?.departureTime != null) {
      chips.add(
        InfoChip(
          icon: Icons.schedule,
          label: DateFormat('h:mm a').format(route!.departureTime!),
        ),
      );
    }

    return chips;
  }

  String get _routeString {
    final dep = route?.estDepartureAirport;
    final arr = route?.estArrivalAirport;
    if (dep != null && arr != null) return '$dep \u2192 $arr';
    if (dep != null) return 'From $dep';
    if (arr != null) return 'To $arr';
    return '';
  }
}
