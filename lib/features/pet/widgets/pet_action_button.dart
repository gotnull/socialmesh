// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';

/// Compact square-ish action button for the pet's bottom action row.
///
/// Optional [onLongPress] enables a Tamagotchi-style hold gesture
/// (tap = primary action, hold = alt action) — used for Charge → Surge.
class PetActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color accent;
  final bool pulsing;

  const PetActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    this.onTap,
    this.onLongPress,
    this.pulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || onLongPress != null;
    final disabledAlpha = 0.35;
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(AppTheme.spacing12),
          decoration: BoxDecoration(
            color: enabled
                ? accent.withValues(alpha: pulsing ? 0.28 : 0.16)
                : accent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(
              color: accent.withValues(
                alpha: enabled ? (pulsing ? 0.6 : 0.35) : 0.1,
              ),
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? accent : accent.withValues(alpha: disabledAlpha),
          ),
        ),
        const SizedBox(height: AppTheme.spacing6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: enabled ? context.textPrimary : context.textTertiary,
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
