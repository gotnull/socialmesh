// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../theme.dart';

/// A panel shown at the end of a wizard flow to confirm completion
/// and guide the user to their next step.
///
/// Displays a success/info icon, headline, description, and optional
/// action buttons for next steps.
class CompletionStatePanel extends StatelessWidget {
  /// Large icon at the top.
  final IconData icon;

  /// Color for the icon and accent elements.
  final Color color;

  /// Main headline (e.g., "Service created").
  final String headline;

  /// Explanatory description of what happened and what comes next.
  final String description;

  /// Optional hint about mesh behavior (e.g., "Works best when nearby").
  final String? meshHint;

  /// Optional primary action button.
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  /// Optional secondary action button.
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  const CompletionStatePanel({
    super.key,
    required this.icon,
    required this.color,
    required this.headline,
    required this.description,
    this.meshHint,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with glow ring
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(icon, size: 40, color: color),
          ),
          const SizedBox(height: AppTheme.spacing24),

          // Headline
          Text(
            headline,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing12),

          // Description
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          // Mesh hint
          if (meshHint != null) ...[
            const SizedBox(height: AppTheme.spacing16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
                vertical: AppTheme.spacing10,
              ),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                border: Border.all(
                  color: context.border.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    size: 16,
                    color: AppTheme.warningYellow,
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Flexible(
                    child: Text(
                      meshHint!,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppTheme.spacing32),

          // Action buttons
          if (primaryActionLabel != null && onPrimaryAction != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPrimaryAction,
                child: Text(primaryActionLabel!),
              ),
            ),
          if (secondaryActionLabel != null && onSecondaryAction != null) ...[
            const SizedBox(height: AppTheme.spacing12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
