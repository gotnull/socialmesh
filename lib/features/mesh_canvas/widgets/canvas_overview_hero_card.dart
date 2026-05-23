// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas overview hero card — Mesh tab.
//
// Visual peer of `_PressureHeroCard` from Mesh Capacity. A large
// gradient-fill stat card that anchors the Mesh tab and gives the
// screen the same enterprise-level presence as NodeDex / Capacity /
// Aether. Composition:
//
//   ┌──────────────────────────────────────────┐
//   │  [N channels]  [K live]                  │
//   │                                          │
//   │  1,234                                   │
//   │  pixels painted                          │
//   │  across the mesh                         │
//   └──────────────────────────────────────────┘
//
// - Top row: small status chips (channel count + live-canvas count).
// - Big number: total painted cells across every materialised mesh
//   canvas. The product is a graffiti wall; the headline number is
//   the cumulative pixel count.
// - Subtitle: shifts between "channel canvases ready · paint to
//   begin" (zero painted) and "across the mesh" (something painted).
//
// All copy comes from ARB keys; no hard-coded strings.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';

/// Renders the overview hero stats card for the Mesh tab.
class CanvasOverviewHeroCard extends StatelessWidget {
  /// Total Meshtastic channels surfaced as latent canvases (configured
  /// channels). Drives the channel-count chip.
  final int channelCount;

  /// Number of channels with at least one painted cell. Hidden when
  /// zero; drives the secondary "live" chip when non-zero.
  final int liveCount;

  /// Sum of painted cells across all materialised mesh canvases.
  /// Drives the big headline number.
  final int totalPaintedCells;

  const CanvasOverviewHeroCard({
    super.key,
    required this.channelCount,
    required this.liveCount,
    required this.totalPaintedCells,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = context.accentColor;
    final hasPaint = totalPaintedCells > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing4,
        AppTheme.spacing16,
        AppTheme.spacing4,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing20,
          AppTheme.spacing20,
          AppTheme.spacing20,
          AppTheme.spacing20,
        ),
        decoration: BoxDecoration(
          // Gradient + border alphas tuned to ~50% of the Capacity
          // hero reference values — softer presence so the hero
          // anchors the screen without dominating the channel cards
          // below.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.08),
              accent.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius20),
          border: Border.all(color: accent.withValues(alpha: 0.15), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppTheme.spacing8,
              runSpacing: AppTheme.spacing8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _HeroChip(
                  icon: Icons.share_outlined,
                  label: l10n.meshCanvasOverviewHeroChannelsChip(channelCount),
                  color: accent,
                  filled: true,
                ),
                if (liveCount > 0)
                  _HeroChip(
                    icon: Icons.brush_outlined,
                    label: l10n.meshCanvasOverviewHeroLiveChip(liveCount),
                    color: context.textSecondary,
                    filled: false,
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatBigNumber(totalPaintedCells),
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    height: 1,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                  child: Text(
                    l10n.meshCanvasOverviewHeroBigUnit,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              hasPaint
                  ? l10n.meshCanvasOverviewHeroSubtitleActive
                  : l10n.meshCanvasOverviewHeroSubtitleQuiet,
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatBigNumber(int n) {
    if (n < 1000) return '$n';
    // Inject thousands separators without a locale lookup so the hero
    // stays snappy on every rebuild.
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// Compact status chip used inside the hero card's top wrap.
/// Filled variant uses the accent color; outline variant uses a faint
/// surface border.
class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;

  const _HeroChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled
        ? color.withValues(alpha: 0.16)
        : Theme.of(context).colorScheme.surface.withValues(alpha: 0.55);
    final border = filled
        ? color.withValues(alpha: 0.40)
        : Theme.of(context).dividerColor.withValues(alpha: 0.30);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: border, width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppTheme.spacing6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.4,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
