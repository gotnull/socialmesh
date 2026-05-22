// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// lint-allow: haptic-feedback — the strip is a pure selection surface;
// haptics are gated by the host screen via `ref.haptics.itemSelect()`
// (which respects the user's settings) on the `onSelect` callback.
// Inline `HapticFeedback.lightImpact()` would bypass that preference
// and double-fire alongside the host's own haptic call.

// Minimal 8-swatch bottom strip for the MeshCanvas viewer.
//
// Spec anchor: docs/canvas/CANVAS_V0_1.md §S0.ux.15 — "active palette
// swatch is one tap away (bottom strip or quick-access)". S7.A scope
// is explicitly 8 colours only; the full 64-colour AppBottomSheet
// surface lands in S7.B.
//
// The strip shows [SocialMeshPalette.quickStripIndices] left-to-right:
// transparent (erase) first, then 7 high-contrast colours. The active
// swatch is ringed; tap any swatch to select.
library;

import 'package:flutter/material.dart';

import '../../../core/canvas/canvas_palette.dart';
import '../../../core/theme.dart';

class CanvasColorStrip extends StatelessWidget {
  /// Currently-selected palette index. Drawn with a ring + thicker
  /// border so the active colour is unambiguous at a glance.
  final int selectedIndex;

  /// Callback fired with the tapped swatch's palette index.
  final void Function(int paletteIndex) onSelect;

  /// Callback fired when the trailing "More" button is tapped. The
  /// host typically calls `showCanvasPaletteSheet` from this.
  /// Optional so the strip can be reused in contexts without the
  /// full palette sheet (currently unused, kept for forward compat).
  final VoidCallback? onMore;

  const CanvasColorStrip({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      // Bottom SafeArea so the strip clears the home indicator on
      // notch / Dynamic Island phones; the container chrome itself
      // extends edge-to-edge.
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        minimum: const EdgeInsets.only(bottom: AppTheme.spacing8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final paletteIndex in SocialMeshPalette.quickStripIndices)
                _Swatch(
                  paletteIndex: paletteIndex,
                  isSelected: paletteIndex == selectedIndex,
                  onTap: () => onSelect(paletteIndex),
                ),
              if (onMore != null) _MoreButton(onTap: onMore!),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final int paletteIndex;
  final bool isSelected;
  final VoidCallback onTap;

  const _Swatch({
    required this.paletteIndex,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = SocialMeshPalette.colorOf(paletteIndex);
    final isTransparent = paletteIndex == SocialMeshPalette.defaultIndex;

    return Semantics(
      label: SocialMeshPalette.nameOf(paletteIndex),
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colour,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withValues(alpha: 0.6),
              width: isSelected ? 3 : 1,
            ),
            // The transparent / erase swatch gets a subtle checker
            // overlay via an inner shadow so it doesn't disappear
            // against the strip background.
            boxShadow: isTransparent
                ? [
                    BoxShadow(
                      color: theme.dividerColor.withValues(alpha: 0.6),
                      blurRadius: 0,
                      spreadRadius: -1,
                      offset: const Offset(0, 0),
                    ),
                  ]
                : null,
          ),
          child: isTransparent
              ? Center(
                  child: Icon(
                    Icons.format_color_reset,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  final VoidCallback onTap;

  const _MoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'More colours', // lint-allow: hardcoded-string
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.more_horiz,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}
