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
/// States (must be visually distinct — the bar shows 4–6 of these
/// side-by-side and the user must be able to tell at a glance which
/// one to tap):
///
///   * Normal              — accent color, clear border, icon bright
///   * Pulsing (actionable) — normal + animated glow ring + bold label
///   * Dimmed (tappable no-op) — accent VISIBLE but muted, label
///       in textSecondary; tap still registers so the engine can
///       toast "already charged" etc.
///   * Disabled (untappable) — NEUTRAL gray, accent removed entirely,
///       label in textTertiary, no tap response. This drops the
///       accent color so disabled reads unambiguously as "off" and
///       can't be confused with a dimmed accent button.
class PetActionButton extends StatefulWidget {
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
  State<PetActionButton> createState() => _PetActionButtonState();
}

class _PetActionButtonState extends State<PetActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.pulsing && _isTappable) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant PetActionButton old) {
    super.didUpdateWidget(old);
    final shouldPulse = widget.pulsing && _isTappable;
    if (shouldPulse && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!shouldPulse && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _isTappable => widget.onTap != null || widget.onLongPress != null;

  @override
  Widget build(BuildContext context) {
    final enabled = _isTappable;
    final pulsing = widget.pulsing && enabled;

    // Resolve all four style tokens at once so the state branches
    // stay readable and easy to audit.
    final Color fillColor;
    final Color borderColor;
    final Color iconColor;
    final Color labelColor;
    final double borderWidth;
    final FontWeight labelWeight;

    if (!enabled) {
      // Disabled = neutral gray. Drop the accent entirely so the
      // button reads as "off" and can't be confused with dimmed.
      final neutral = context.textTertiary;
      fillColor = neutral.withValues(alpha: 0.04);
      borderColor = neutral.withValues(alpha: 0.22);
      iconColor = neutral.withValues(alpha: 0.50);
      labelColor = neutral.withValues(alpha: 0.60);
      borderWidth = 1.0;
      labelWeight = FontWeight.w600;
    } else if (widget.dimmed) {
      // Dimmed = tappable but no-op. Accent is VISIBLE so the user
      // can still identify "which button is Charge"; label drops to
      // textSecondary so it reads as "not the one to tap right now."
      fillColor = widget.accent.withValues(alpha: 0.08);
      borderColor = widget.accent.withValues(alpha: 0.40);
      iconColor = widget.accent.withValues(alpha: 0.70);
      labelColor = context.textSecondary;
      borderWidth = 1.0;
      labelWeight = FontWeight.w600;
    } else if (pulsing) {
      // Pulsing = urgent / recommended. Strongest contrast + label
      // bolded to draw the eye. Glow ring is applied separately as
      // an animated BoxShadow below.
      fillColor = widget.accent.withValues(alpha: 0.28);
      borderColor = widget.accent.withValues(alpha: 0.88);
      iconColor = widget.accent;
      labelColor = context.textPrimary;
      borderWidth = 1.5;
      labelWeight = FontWeight.w700;
    } else {
      // Normal actionable.
      fillColor = widget.accent.withValues(alpha: 0.16);
      borderColor = widget.accent.withValues(alpha: 0.50);
      iconColor = widget.accent;
      labelColor = context.textPrimary;
      borderWidth = 1.0;
      labelWeight = FontWeight.w600;
    }

    final iconBox = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Icon(widget.icon, size: 22, color: iconColor),
    );

    // Animated glow ring — only allocated when pulsing. The
    // SingleTickerProviderStateMixin doesn't spin if we aren't
    // calling `_pulseController.repeat()` in this branch, so the
    // non-pulsing path has zero animation cost.
    final iconWithOptionalPulse = pulsing
        ? AnimatedBuilder(
            animation: _pulseController,
            builder: (_, child) {
              final t = _pulseController.value; // 0..1..0 triangle
              final glowAlpha = 0.18 + 0.30 * (1.0 - t);
              final spread = 2.0 + 8.0 * t;
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: glowAlpha),
                      blurRadius: 16.0,
                      spreadRadius: spread,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: iconBox,
          )
        : iconBox;

    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWithOptionalPulse,
        const SizedBox(height: AppTheme.spacing6),
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: labelWeight,
            letterSpacing: 0.4,
            color: labelColor,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ],
    );
    return Expanded(
      child: BouncyTap(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
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
