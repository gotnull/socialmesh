// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// A card that presents a single choice in a guided flow step.
///
/// Displays an icon, title, description, and optional trailing widget.
/// Tapping selects the card (indicated by a colored border and checkmark).
///
/// Used as a selection tile in wizard steps where the user picks one
/// option from several (e.g., "What do you want to create?").
class StepChoiceCard extends StatelessWidget {
  /// Primary icon for this choice.
  final IconData icon;

  /// Choice title (short, action-oriented).
  final String title;

  /// One-line description in plain language.
  final String description;

  /// Accent color for selected state border and icon.
  final Color accentColor;

  /// Whether this choice is currently selected.
  final bool isSelected;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  /// Optional trailing widget (e.g., a badge or chevron).
  final Widget? trailing;

  const StepChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
    this.isSelected = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap?.call();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.08)
              : context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(
            color: isSelected
                ? accentColor.withValues(alpha: 0.6)
                : context.border.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.15)
                    : context.surface,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? accentColor : context.textSecondary,
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppTheme.spacing8),
              trailing!,
            ] else if (isSelected) ...[
              const SizedBox(width: AppTheme.spacing8),
              Icon(Icons.check_circle, size: 20, color: accentColor),
            ],
          ],
        ),
      ),
    );
  }
}
