// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../services/opensky_service.dart';

/// Bottom sheet for searching and selecting active flights from OpenSky.
class FlightSearchSheet extends StatefulWidget {
  const FlightSearchSheet({super.key});

  /// Show the flight search sheet and return the selected flight.
  static Future<ActiveFlightInfo?> show(BuildContext context) {
    return AppBottomSheet.show<ActiveFlightInfo>(
      context: context,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top safe area padding (Dynamic Island)
        SizedBox(height: MediaQuery.of(context).padding.top),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Enter flight number (e.g. UA123, BA456)',
              hintStyle: TextStyle(color: context.textTertiary),
              prefixIcon: Icon(
                Icons.flight_takeoff,
                color: context.textSecondary,
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
              fillColor: context.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.accentColor, width: 2),
              ),
            ),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            onChanged: _onSearchChanged,
          ),
        ),

        const SizedBox(height: 16),

        // Results
        Flexible(child: _buildResults()),

        // Bottom padding
        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ],
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
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final flight = _results[index];
        return _FlightResultTile(
          flight: flight,
          onTap: () => _selectFlight(flight),
        );
      },
    );
  }

  Widget _buildHint() {
    return Padding(
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
    );
  }

  Widget _buildEmpty() {
    return Padding(
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
    );
  }

  Widget _buildError() {
    return Padding(
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
    );
  }
}

class _FlightResultTile extends StatelessWidget {
  final ActiveFlightInfo flight;
  final VoidCallback onTap;

  const _FlightResultTile({required this.flight, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      flight.callsign,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _buildSubtitle(),
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
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
                    '${flight.altitudeFeet!.toStringAsFixed(0)} ft',
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

  String _buildSubtitle() {
    final parts = <String>[];

    if (flight.originCountry != null) {
      parts.add(flight.originCountry!);
    }

    if (flight.onGround) {
      parts.add('On ground');
    } else if (flight.velocityKnots != null) {
      parts.add('${flight.velocityKnots!.toStringAsFixed(0)} kts');
    }

    return parts.isEmpty ? 'Active flight' : parts.join(' · ');
  }
}
