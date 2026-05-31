// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// A filter chip with a colored status dot (or icon), label, and optional
/// count badge.
///
/// Designed for status-based filtering (e.g. Open, Resolved, Responded).
/// When [icon] is provided it replaces the dot indicator.
///
/// ```dart
/// StatusFilterChip(
///   label: 'Open',
///   count: 12,
///   color: Colors.amber,
///   isSelected: true,
///   onTap: () => setState(() => _filter = Filter.open),
/// )
/// ```
class StatusFilterChip extends StatelessWidget {
  /// Display label for the filter.
  final String label;

  /// Optional count to display next to the label.
  final int? count;

  /// Accent color for the dot/icon, selected border, and count text.
  final Color? color;

  /// Optional icon to display instead of the colored dot.
  final IconData? icon;

  /// Whether this chip is currently selected.
  final bool isSelected;

  /// Called when the chip is tapped.
  final VoidCallback onTap;

  const StatusFilterChip({
    super.key,
    required this.label,
    this.count,
    this.color,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primaryBlue;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing12,
          vertical: AppTheme.spacing8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withValues(alpha: 0.15) : context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius20),
          border: Border.all(
            color: isSelected
                ? chipColor
                : context.isDarkMode
                ? Colors.white.withValues(alpha: 0.08)
                : context.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(
                icon,
                size: 14,
                color: isSelected ? chipColor : context.textSecondary,
              )
            else
              Container(
                width: AppTheme.spacing8,
                height: AppTheme.spacing8,
                decoration: BoxDecoration(
                  color: chipColor,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: AppTheme.spacing6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? chipColor : context.textSecondary,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: AppTheme.spacing5),
              Text(
                '${count!}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? chipColor : context.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
