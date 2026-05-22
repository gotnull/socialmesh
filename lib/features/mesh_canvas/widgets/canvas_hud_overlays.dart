// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Two pure-presentational overlays the host screen lays on top of
// the MeshCanvas viewer Stack:
//
//   - [CanvasIdentityChip]: a tiny atmospheric pill anchored top-left
//     that names the canvas scope (Local Device Canvas / Mesh Canvas).
//     Subtitled with a one-line state hint ("Offline sandbox · paints
//     remain local"). Lives directly on the canvas surface gradient
//     so it doesn't steal chrome from the app bar.
//
//   - [CanvasColorHud]: a tiny centered pill above the bottom strip
//     that names the currently-selected swatch ("Red" / "Eraser") and
//     shows its colour as a leading dot. Always-on so the user never
//     has to scan back to the strip to remember "what am I painting
//     with?" while panning.
//
// Both are intentionally < 200pt wide and < 32pt tall — they exist
// to *frame* the canvas, not compete with it. No animations beyond
// a 120ms colour cross-fade on the HUD pill so colour changes feel
// snappy without being noisy. Future budget / cooldown indicators
// can extend these chips without changing the host layout.
library;

import 'package:flutter/material.dart';

import '../../../core/canvas/canvas_palette.dart';
import '../../../core/theme.dart';

/// Small contextual chip naming the canvas scope. Placed on the
/// canvas viewport surface (NOT in the app bar) so the app bar can
/// stay reserved for navigation + help.
class CanvasIdentityChip extends StatelessWidget {
  /// Short scope label, e.g. "Local Device Canvas".
  final String label;

  /// One-line atmospheric subtitle, e.g.
  /// "Offline sandbox · paints remain local". Optional.
  final String? subtitle;

  /// Leading icon — `Icons.smartphone_outlined` for local,
  /// `Icons.share_outlined` for mesh in S7-final.
  final IconData icon;

  const CanvasIdentityChip({
    super.key,
    required this.label,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.4),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.textSecondary),
          const SizedBox(width: AppTheme.spacing8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                  letterSpacing: 0.6,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.textTertiary,
                      letterSpacing: 0.4,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small "you are painting with" HUD pill — a coloured dot + short
/// name. Lives just above the bottom colour strip so it sits where
/// the user's thumb already is. Use [eraserLabel] for the
/// transparent / index-0 case where a "colour" isn't meaningful.
class CanvasColorHud extends StatelessWidget {
  final int paletteIndex;

  /// Localized name used when the selected swatch IS the erase /
  /// transparent sentinel. Caller resolves the localization so this
  /// widget stays presentational.
  final String eraserLabel;

  const CanvasColorHud({
    super.key,
    required this.paletteIndex,
    required this.eraserLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEraser = paletteIndex == SocialMeshPalette.defaultIndex;
    final colour = SocialMeshPalette.colorOf(paletteIndex);
    final name = isEraser
        ? eraserLabel
        : SocialMeshPalette.nameOf(paletteIndex);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.45),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEraser)
            Icon(
              Icons.format_color_reset,
              size: 14,
              color: context.textSecondary,
            )
          else
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colour,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.7),
                  width: 0.6,
                ),
              ),
            ),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
              letterSpacing: 0.4,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
