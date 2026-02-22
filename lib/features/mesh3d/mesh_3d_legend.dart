// SPDX-License-Identifier: GPL-3.0-or-later

// Mesh 3D Legend
//
// A compact, glass-styled legend overlay for the 3D mesh visualization.
// Displays colour-coded items relevant to the active view mode. Uses
// backdrop blur and translucent card styling consistent with the app's
// glass design language, replacing the old opaque black box.

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'mesh_3d_models.dart';

// ---------------------------------------------------------------------------
// Mesh3DLegend
// ---------------------------------------------------------------------------

/// A compact legend overlay that shows colour-coded items for the active
/// [Mesh3DViewMode].
///
/// Rendered as a glass pill with backdrop blur, positioned by the caller
/// (typically bottom-left of the 3D viewport). The legend automatically
/// adjusts its content based on the current view mode.
class Mesh3DLegend extends StatelessWidget {
  /// The active view mode — determines which legend items are shown.
  final Mesh3DViewMode mode;

  const Mesh3DLegend({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final items = _itemsForMode(context, mode);

    if (items.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: context.card.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.border.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(mode.icon, size: 11, color: context.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: context.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              // Legend items
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: _LegendItem(color: item.color, label: item.label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns the legend items appropriate for the given view mode.
  static List<_LegendEntry> _itemsForMode(
    BuildContext context,
    Mesh3DViewMode mode,
  ) {
    switch (mode) {
      case Mesh3DViewMode.signalStrength:
        return [
          _LegendEntry(color: AppTheme.successGreen, label: 'Good signal'),
          _LegendEntry(color: AppTheme.warningYellow, label: 'Fair signal'),
          _LegendEntry(color: AppTheme.errorRed, label: 'Poor signal'),
          _LegendEntry(color: AccentColors.cyan, label: 'SNR bar'),
        ];
      case Mesh3DViewMode.activity:
        return [
          _LegendEntry(color: AppTheme.errorRed, label: 'Active now'),
          _LegendEntry(color: Colors.blue.shade700, label: 'Stale / idle'),
        ];
      case Mesh3DViewMode.topology:
        return [
          _LegendEntry(color: AppTheme.primaryBlue, label: 'Your node'),
          _LegendEntry(color: AppTheme.successGreen, label: 'Active peer'),
          _LegendEntry(color: AppTheme.warningYellow, label: 'Fading peer'),
          _LegendEntry(color: Colors.grey.shade500, label: 'Offline'),
        ];
      case Mesh3DViewMode.terrain:
        return [
          _LegendEntry(color: AppTheme.primaryBlue, label: 'Your node'),
          _LegendEntry(color: AppTheme.successGreen, label: 'Active'),
          _LegendEntry(color: AppTheme.warningYellow, label: 'Fading'),
          _LegendEntry(color: Colors.grey.shade500, label: 'Offline'),
          _LegendEntry(color: Colors.green.shade800, label: 'Low altitude'),
          _LegendEntry(color: Colors.brown.shade400, label: 'High altitude'),
        ];
    }
  }
}

// ---------------------------------------------------------------------------
// Internal data + widgets
// ---------------------------------------------------------------------------

class _LegendEntry {
  final Color color;
  final String label;

  const _LegendEntry({required this.color, required this.label});
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 3,
                spreadRadius: 0,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: context.textSecondary,
          ),
        ),
      ],
    );
  }
}
