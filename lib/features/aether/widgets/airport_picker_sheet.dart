// SPDX-License-Identifier: GPL-3.0-or-later

// Airport Picker Screen — searchable full-screen airport selector.
//
// Full-screen route (same pattern as FlightSearchSheet).
// Displays all 1,173 large airports from the OurAirports dataset.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../data/airports.dart';

/// Maximum search query length for airport search.
const int _maxSearchLength = 40;

/// Full-screen airport picker. Returns a selected [Airport] or null.
class AirportPickerSheet extends StatefulWidget {
  final String title;
  final String? initialCode;

  const AirportPickerSheet({
    super.key,
    this.title = 'Select Airport',
    this.initialCode,
  });

  /// Show the airport picker and return the selected airport.
  static Future<Airport?> show(
    BuildContext context, {
    String title = 'Select Airport',
    String? initialCode,
  }) {
    return Navigator.of(context).push<Airport>(
      MaterialPageRoute(
        builder: (_) =>
            AirportPickerSheet(title: title, initialCode: initialCode),
      ),
    );
  }

  @override
  State<AirportPickerSheet> createState() => _AirportPickerSheetState();
}

class _AirportPickerSheetState extends State<AirportPickerSheet> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<Airport> _filtered = [];
  bool _hasQuery = false;

  @override
  void initState() {
    super.initState();
    _filtered = kAirports;
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _hasQuery = query.isNotEmpty;
      if (query.isEmpty) {
        _filtered = kAirports;
      } else {
        _filtered = kAirports.where((a) => a.matches(query)).toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _focusNode.requestFocus();
  }

  void _selectAirport(Airport airport) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(airport);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: GlassScaffold(
        title: widget.title,
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
                  controller: _searchController,
                  focusNode: _focusNode,
                  maxLength: _maxSearchLength,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search by code, city, or name',
                    hintStyle: TextStyle(color: context.textTertiary),
                    prefixIcon: Icon(Icons.search, color: context.textTertiary),
                    suffixIcon: _hasQuery
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

          // Results count
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                _hasQuery
                    ? '${_filtered.length} result${_filtered.length == 1 ? '' : 's'}'
                    : '${kAirports.length} airports',
                style: TextStyle(fontSize: 12, color: context.textTertiary),
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

          // Content
          if (_filtered.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final airport = _filtered[index];
                final isSelected =
                    widget.initialCode != null &&
                    (airport.iata == widget.initialCode!.toUpperCase() ||
                        airport.icao == widget.initialCode!.toUpperCase());
                return _AirportTile(
                  airport: airport,
                  isSelected: isSelected,
                  onTap: () => _selectAirport(airport),
                );
              }, childCount: _filtered.length),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight_outlined, size: 48, color: context.textTertiary),
            const SizedBox(height: 12),
            Text(
              'No airports found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You can still type the code manually',
              style: TextStyle(fontSize: 13, color: context.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _AirportTile extends StatelessWidget {
  final Airport airport;
  final bool isSelected;
  final VoidCallback onTap;

  const _AirportTile({
    required this.airport,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: isSelected ? context.accentColor.withValues(alpha: 0.1) : null,
        child: Row(
          children: [
            // IATA code badge
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.accentColor.withValues(alpha: 0.2)
                    : context.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? context.accentColor : context.border,
                ),
              ),
              child: Text(
                airport.iata,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppTheme.fontFamily,
                  color: isSelected ? context.accentColor : context.textPrimary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Airport info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    airport.city,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${airport.name} (${airport.icao})',
                    style: TextStyle(fontSize: 12, color: context.textTertiary),
                  ),
                ],
              ),
            ),
            // Country
            Text(
              airport.country,
              style: TextStyle(
                fontSize: 12,
                color: context.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle, color: context.accentColor, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
