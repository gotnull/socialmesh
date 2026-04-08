// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../theme.dart';

/// A read-only summary card used in wizard review / completion steps.
///
/// Shows a list of key-value pairs with optional icons. Designed for
/// confirming choices before a wizard commits an action.
class SummaryCard extends StatelessWidget {
  /// Section title above the summary rows.
  final String title;

  /// Optional icon next to the title.
  final IconData? titleIcon;

  /// Color for the title icon and accent line.
  final Color? accentColor;

  /// Key-value rows to display.
  final List<SummaryRow> rows;

  const SummaryCard({
    super.key,
    required this.title,
    this.titleIcon,
    this.accentColor,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? context.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: context.border.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                if (titleIcon != null) ...[
                  Icon(titleIcon, size: 18, color: accent),
                  const SizedBox(width: AppTheme.spacing8),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...rows.asMap().entries.map((entry) {
            final isLast = entry.key == rows.length - 1;
            return _SummaryRowTile(row: entry.value, showBottomBorder: !isLast);
          }),
        ],
      ),
    );
  }
}

/// A single key-value row in a [SummaryCard].
class SummaryRow {
  /// Label for this row (e.g., "Type", "Audience").
  final String label;

  /// Value to display (e.g., "Bulletin Board", "Anyone nearby").
  final String value;

  /// Optional icon for the row.
  final IconData? icon;

  /// Optional color for the icon.
  final Color? iconColor;

  const SummaryRow({
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
  });
}

class _SummaryRowTile extends StatelessWidget {
  final SummaryRow row;
  final bool showBottomBorder;

  const _SummaryRowTile({required this.row, required this.showBottomBorder});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing10,
      ),
      decoration: showBottomBorder
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: context.border.withValues(alpha: 0.06),
                ),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (row.icon != null) ...[
            Icon(
              row.icon,
              size: 16,
              color: row.iconColor ?? context.textTertiary,
            ),
            const SizedBox(width: AppTheme.spacing8),
          ],
          SizedBox(
            width: 100,
            child: Text(
              row.label,
              style: TextStyle(fontSize: 13, color: context.textTertiary),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              row.value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
