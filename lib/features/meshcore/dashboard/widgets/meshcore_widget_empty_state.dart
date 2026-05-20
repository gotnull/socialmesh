// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../../core/theme.dart';

/// Canonical empty-state shape for MeshCore dashboard widgets.
///
/// Every "no data yet" surface inside a dashboard tile MUST route
/// through this widget so padding, spacing, and tile shape stay
/// identical across Network Overview / Recent Messages / Signal
/// Strength / Channel Activity / Mesh Health / Node Map. A single
/// place to tweak the look is the only way to keep four near-
/// identical empty states from drifting visually.
///
/// Layout invariants:
///   - Fixed 140 px tile body so the empty state has the same height
///     as a typical populated tile (no jarring resize when the data
///     arrives).
///   - Vertical content centered inside the box (icon at top of column,
///     title under it, optional subtitle under the title).
///   - Symmetric horizontal padding so multi-line subtitles wrap with
///     reasonable margins on both sides.
class MeshCoreWidgetEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const MeshCoreWidgetEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing24,
          vertical: AppTheme.spacing16,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: context.textTertiary),
              const SizedBox(height: AppTheme.spacing12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary,
                ),
                textAlign: TextAlign.center,
                softWrap: true,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppTheme.spacing6),
                Text(
                  subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
                  textAlign: TextAlign.center,
                  softWrap: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
