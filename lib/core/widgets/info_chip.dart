// SPDX-License-Identifier: GPL-3.0-or-later

// InfoChip — compact metadata badge for list tiles.
//
// Use inside a Wrap widget so chips flow to the next line instead of
// truncating. The label text is wrapped in Flexible so even a single
// chip wider than the available space will soft-wrap rather than overflow.
//
// Usage:
//   Wrap(
//     spacing: 6,
//     runSpacing: 4,
//     children: [
//       InfoChip(icon: Icons.public, label: 'United Arab Emirates'),
//       InfoChip(icon: Icons.height, label: '33,000 ft'),
//       InfoChip(icon: Icons.speed, label: '499 kts'),
//     ],
//   )

import 'package:flutter/material.dart';

import '../theme.dart';

/// A compact chip showing an icon + label, styled for list tile metadata rows.
///
/// Place inside a [Wrap] to avoid truncation. The chip sizes itself to its
/// content (`MainAxisSize.min`) while the label uses [Flexible] so it can
/// soft-wrap when constrained.
class InfoChip extends StatelessWidget {
  /// The leading icon displayed at 12dp.
  final IconData icon;

  /// The text label displayed next to the icon.
  final String label;

  /// Color applied to both the icon and label text.
  final Color? color;

  /// Background color of the chip container.
  final Color? backgroundColor;

  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? context.textTertiary;
    final chipBackground =
        backgroundColor ?? context.textPrimary.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: chipColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: chipColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
