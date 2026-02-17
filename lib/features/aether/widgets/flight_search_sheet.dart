// SPDX-License-Identifier: GPL-3.0-or-later

// Flight Search Screen — search OpenSky for active flights.
//
// Full-screen route (same pattern as UserSearchScreen / SignalFeedScreen).
// Single debounced search path — no duplicate calls, no race conditions.

import 'dart:math' as math;

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
  final Set<String> _routeLoading = {};

  _SearchState _state = _SearchState.idle;
  List<ActiveFlightInfo> _results = [];
  String _errorMessage = '';

  /// Monotonic counter — incremented on every text change. Async search
  /// results are discarded when they arrive for an outdated generation,
  /// preventing stale partial-match results from overwriting newer state.
  int _searchGeneration = 0;

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
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Search logic — explicit submit only (no auto-search on typing)
  // ---------------------------------------------------------------------------

  /// Called on every keystroke — only updates UI state (clear button, idle
  /// reset). Does NOT trigger a search. The user must press Enter / Search.
  void _onTextChanged(String text) {
    // Rebuild so the clear button appears/disappears
    setState(() {
      // If the user clears the field, reset to idle
      if (text.trim().length < 2 && _state != _SearchState.idle) {
        _state = _SearchState.idle;
        _results = [];
      }
    });
  }

  /// Explicit submit (keyboard Search button or search icon tap).
  /// This is the ONLY path that fires an OpenSky query.
  void _onSubmitted(String text) {
    _searchGeneration++;

    final query = text.trim().toUpperCase();
    if (query.length < 2) {
      setState(() {
        _state = _SearchState.idle;
        _results = [];
      });
      return;
    }

    // Dismiss keyboard so results are visible
    FocusScope.of(context).unfocus();

    setState(() => _state = _SearchState.loading);

    _executeSearch(query);
  }

  Future<void> _executeSearch(String query) async {
    final generation = _searchGeneration;
    AppLogging.aether('FlightSearch: searching "$query" (gen=$generation)');

    try {
      final results = await _openSky.searchActiveFlights(query, limit: 30);
      if (!mounted) return;

      // Discard stale results — a newer query has been issued while we waited
      // for the OpenSky response. Without this guard, slow responses for
      // partial queries (e.g. "MH") overwrite results for the final query
      // (e.g. "MH370").
      if (generation != _searchGeneration) {
        AppLogging.aether(
          'FlightSearch: discarding stale results for "$query" '
          '(gen=$generation, current=$_searchGeneration)',
        );
        return;
      }

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
      // Also check generation for error state — don't show errors for
      // superseded queries.
      if (generation != _searchGeneration) return;
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
      _routeLoading.add(f.icao24!);
    }
    if (mounted) setState(() {});

    const batchSize = 3;
    for (var i = 0; i < toFetch.length; i += batchSize) {
      if (!mounted) return;
      final batch = toFetch.skip(i).take(batchSize);
      await Future.wait(
        batch.map((f) async {
          try {
            final route = await _openSky.lookupAircraftRoute(f.icao24!);
            if (mounted) {
              setState(() {
                _routeCache[f.icao24!] = route;
                _routeLoading.remove(f.icao24!);
              });
            }
          } catch (_) {
            if (mounted) {
              setState(() => _routeLoading.remove(f.icao24!));
            }
          }
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
                  onSubmitted: _onSubmitted,
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
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Search button — visible tap target
                              IconButton(
                                icon: Icon(
                                  Icons.search,
                                  color: context.accentColor,
                                ),
                                onPressed: () => _onSubmitted(_controller.text),
                                tooltip: 'Search',
                              ),
                              // Clear button
                              IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: context.textTertiary,
                                ),
                                onPressed: _clearSearch,
                              ),
                            ],
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
                'Type a callsign and press Search\nto find flights currently in the air',
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
              final routeLoading =
                  flight.icao24 != null &&
                  _routeLoading.contains(flight.icao24);
              return _FlightTile(
                flight: flight,
                route: route,
                routeLoading: routeLoading,
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
  final bool routeLoading;
  final VoidCallback onTap;

  const _FlightTile({
    required this.flight,
    this.route,
    this.routeLoading = false,
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

                    // Route — own row (with loading skeleton)
                    if (hasRoute) ...[
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Row(
                          key: ValueKey(
                            'route-${route?.estDepartureAirport}-${route?.estArrivalAirport}',
                          ),
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
                      ),
                    ] else if (routeLoading) ...[
                      const SizedBox(height: 4),
                      _RouteSkeletonLine(),
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

// =============================================================================
// Route skeleton shimmer (while route data is loading)
// =============================================================================

class _RouteSkeletonLine extends StatefulWidget {
  @override
  State<_RouteSkeletonLine> createState() => _RouteSkeletonLineState();
}

class _RouteSkeletonLineState extends State<_RouteSkeletonLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) {
        final t = _shimmer.value;
        final shimmerOpacity =
            0.08 + 0.08 * (0.5 + 0.5 * math.cos(t * 2 * math.pi));
        return Row(
          children: [
            Icon(
              Icons.route,
              size: 13,
              color: context.textTertiary.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 4),
            Container(
              width: 100,
              height: 13,
              decoration: BoxDecoration(
                color: context.textTertiary.withValues(alpha: shimmerOpacity),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        );
      },
    );
  }
}
