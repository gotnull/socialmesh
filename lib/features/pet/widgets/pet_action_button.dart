// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';

/// Compact square-ish action button for the pet's bottom action row.
///
/// Optional [onLongPress] enables a Tamagotchi-style hold gesture
/// (tap = primary action, hold = alt action) — used for Charge → Surge.
///
/// [dimmed] is a soft "this action would be a no-op right now" visual —
/// the button is still tappable (so the user gets a toast explaining
/// why), but the fill/icon are muted to cue that nothing will change.
/// Different from a disabled button (no onTap), which is untappable.
class PetActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color accent;
  final bool pulsing;
  final bool dimmed;

  const PetActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    this.onTap,
    this.onLongPress,
    this.pulsing = false,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || onLongPress != null;
    const disabledAlpha = 0.35;
    final effectiveFillAlpha = !enabled
        ? 0.05
        : dimmed
        ? 0.08
        : pulsing
        ? 0.28
        : 0.16;
    final effectiveBorderAlpha = !enabled
        ? 0.1
        : dimmed
        ? 0.18
        : pulsing
        ? 0.6
        : 0.35;
    final effectiveIconAlpha = !enabled
        ? disabledAlpha
        : dimmed
        ? 0.55
        : 1.0;
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(AppTheme.spacing12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: effectiveFillAlpha),
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(
              color: accent.withValues(alpha: effectiveBorderAlpha),
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: accent.withValues(alpha: effectiveIconAlpha),
          ),
        ),
        const SizedBox(height: AppTheme.spacing6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: (!enabled || dimmed)
                ? context.textTertiary
                : context.textPrimary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ],
    );
    return Expanded(
      child: BouncyTap(
        onTap: onTap,
        onLongPress: onLongPress,
        enabled: enabled,
        scaleFactor: 0.9,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing2),
          child: child,
        ),
      ),
    );
  }
}
