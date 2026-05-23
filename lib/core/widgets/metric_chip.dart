// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MetricChip — a compact, low-noise icon+value chip used in list-tile
// metadata clusters across the app (NodeDex co-seen counts, MeshCanvas
// channel-card stats, etc.).
//
// Visual contract:
//   - Subtle tertiary-color outline + ~10% fill of the same color.
//   - Icon (11 px) + value text (10 px, w600, slight letter-spacing).
//   - Optional tooltip on long-press.
//
// Use this wherever a list tile needs "iconish small stat badge"
// next to a label. Never hand-roll the shape — pull it from here.
library;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Compact metric badge. Renders an icon + value pair inside a
/// tinted outline pill.
class MetricChip extends StatelessWidget {
  /// Icon shown to the left of the value.
  final IconData icon;

  /// Short value string ("12", "2h ago", "98 painted", etc.).
  final String value;

  /// Long-press tooltip. Set when the icon's meaning isn't obvious
  /// at a glance.
  final String? tooltip;

  /// Optional color override. Defaults to `context.textTertiary` so
  /// the chip reads as ambient metadata, not a primary affordance.
  final Color? color;

  const MetricChip({
    super.key,
    required this.icon,
    required this.value,
    this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.textTertiary;
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing3,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: c.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: c),
          const SizedBox(width: AppTheme.spacing3),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: c,
              fontFamily: AppTheme.fontFamily,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
    final tip = tooltip;
    if (tip == null) return chip;
    return Tooltip(message: tip, child: chip);
  }
}
