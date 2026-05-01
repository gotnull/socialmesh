// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Stat tile used inside the NodeDex Constellation bento grid.
//
// Mirrors the "2,307 users in the City" / "642 events in Chennai"
// pastel-gradient tiles in the events-dashboard reference: a soft
// directional gradient, an optional small icon-badge in the corner,
// a big bold value, and a quiet subtitle below.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme.dart';

class NodeConstellationStatTile extends StatelessWidget {
  /// Big value (e.g. "320", "1m ago").
  final String value;

  /// Quiet subtitle below the value.
  final String label;

  /// Accent colour driving the tile's tinted gradient.
  final Color accent;

  /// Optional icon shown in the top-right corner of the tile.
  final IconData? icon;

  /// Optional tap handler.
  final VoidCallback? onTap;

  const NodeConstellationStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.accent,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.32),
              accent.withValues(alpha: 0.14),
              context.card,
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing14,
          AppTheme.spacing12,
          AppTheme.spacing14,
          AppTheme.spacing12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                    border: Border.all(color: accent.withValues(alpha: 0.45)),
                  ),
                  child: Icon(icon, size: 14, color: accent),
                ),
              ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
                fontFamily: AppTheme.fontFamily,
                height: 1.05,
              ),
            ),
            const SizedBox(height: AppTheme.spacing2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
                fontFamily: AppTheme.fontFamily,
                height: 1.3,
              ),
              softWrap: true,
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return tile;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: tile,
    );
  }
}
