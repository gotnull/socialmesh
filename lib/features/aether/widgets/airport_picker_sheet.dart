// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../data/airports.dart';

/// Maximum search query length for airport search.
const int _maxSearchLength = 40;

/// A bottom sheet that lets the user search and pick an airport.
///
/// Returns the selected [Airport], or `null` if dismissed.
///
/// Usage:
/// ```dart
/// final airport = await AirportPickerSheet.show(
///   context,
///   title: 'Departure Airport',
/// );
/// if (airport != null) {
///   _departureController.text = airport.iata;
/// }
/// ```
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
    return AppBottomSheet.show<Airport>(
      context: context,
      padding: EdgeInsets.zero,
      child: AirportPickerSheet(title: title, initialCode: initialCode),
    );
  }

  @override
  State<AirportPickerSheet> createState() => _AirportPickerSheetState();
}

class _AirportPickerSheetState extends State<AirportPickerSheet> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<Airport> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = kAirports;
    _searchController.addListener(_onSearchChanged);
    // Auto-focus search after sheet animation
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _focusNode.requestFocus();
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
      if (query.isEmpty) {
        _filtered = kAirports;
      } else {
        _filtered = kAirports.where((a) => a.matches(query)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: context.textTertiary),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              maxLength: _maxSearchLength,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by code, city, or name',
                hintStyle: TextStyle(color: context.textTertiary),
                prefixIcon: Icon(
                  Icons.search,
                  color: context.textTertiary,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                        },
                        icon: Icon(
                          Icons.clear,
                          color: context.textTertiary,
                          size: 20,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: context.card,
                counterText: '',
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
                  borderSide: BorderSide(color: context.accentColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Results count
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Text(
                  _searchController.text.isEmpty
                      ? '${kAirports.length} airports'
                      : '${_filtered.length} result${_filtered.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: context.textTertiary),
                ),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, color: context.border),

          // Airport list
          Expanded(
            child: _filtered.isEmpty
                ? _buildEmptyState()
                : GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: ListView.builder(
                      itemCount: _filtered.length,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemBuilder: (context, index) {
                        final airport = _filtered[index];
                        final isSelected =
                            widget.initialCode != null &&
                            (airport.iata ==
                                    widget.initialCode!.toUpperCase() ||
                                airport.icao ==
                                    widget.initialCode!.toUpperCase());
                        return _AirportTile(
                          airport: airport,
                          isSelected: isSelected,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).pop(airport);
                          },
                        );
                      },
                    ),
                  ),
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
