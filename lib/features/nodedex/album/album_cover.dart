// SPDX-License-Identifier: GPL-3.0-or-later

// Album Cover — premium collector stats dashboard.
//
// The album cover sits at the top of the album grid view and serves
// as the visual anchor for the entire collector experience. It
// communicates the user's collection status at a glance:
//
//   - Explorer title and emblem (earned through discovery)
//   - Rarity breakdown as a proportional stacked bar
//   - Key collection metrics (nodes, encounters, regions, days)
//   - Trait completion progress as a ring of dots
//   - Highest rarity badge with glow treatment
//
// Visual design:
//   - Dark card with subtle gradient background
//   - Gold/accent ornamental borders matching the sci-fi aesthetic
//   - Monospace numerals for all statistics
//   - Compact layout fitting within ~260dp height
//   - Smooth entrance animation (fade + slide up)
//
// Data source:
//   - Reads from collectionProgressProvider (derived, no side effects)
//   - All rendering is purely presentational
//   - No protocol-specific logic
//
// Performance:
//   - Single widget tree, no per-frame allocations
//   - Background painter cached via shouldRepaint
//   - Entrance animation uses a single AnimationController

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../models/nodedex_entry.dart';
import '../widgets/sigil_card.dart';
import 'album_constants.dart';
import 'album_providers.dart';

// =============================================================================
// Album Cover Widget
// =============================================================================

/// Premium stats dashboard displayed at the top of the album grid.
///
/// Shows the user's explorer title, collection metrics, rarity breakdown,
/// and trait completion in a visually rich card that establishes the
/// collector album aesthetic.
///
/// The cover animates in on first build with a subtle fade + slide-up
/// transition. Set [animate] to false for reduce-motion or testing.
///
/// Usage:
/// ```dart
/// AlbumCover(animate: !reduceMotion)
/// ```
class AlbumCover extends ConsumerStatefulWidget {
  /// Whether to play the entrance animation.
  final bool animate;

  const AlbumCover({super.key, this.animate = true});

  @override
  ConsumerState<AlbumCover> createState() => _AlbumCoverState();
}

class _AlbumCoverState extends ConsumerState<AlbumCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: AlbumConstants.coverEntranceDuration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    if (widget.animate) {
      _entranceController.forward();
    } else {
      _entranceController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(collectionProgressProvider);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AlbumConstants.coverMarginH,
            vertical: AlbumConstants.coverMarginV,
          ),
          child: _CoverCard(progress: progress),
        ),
      ),
    );
  }
}

// =============================================================================
// Cover Card — the main container
// =============================================================================

class _CoverCard extends StatelessWidget {
  final CollectionProgress progress;

  const _CoverCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final highestRarity = progress.highestRarity;

    return Container(
      constraints: const BoxConstraints(minHeight: AlbumConstants.coverHeight),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AlbumConstants.coverBorderRadius),
        border: Border.all(
          color: highestRarity.borderColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: highestRarity.glowColor.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          AlbumConstants.coverBorderRadius - 1.5,
        ),
        child: CustomPaint(
          painter: _CoverBackgroundPainter(
            isDark: context.isDarkMode,
            accentColor: highestRarity.borderColor,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Explorer title section
                _ExplorerTitleSection(progress: progress),
                const SizedBox(height: 16),

                // Ornamental divider
                _CoverDivider(color: highestRarity.borderColor),
                const SizedBox(height: 14),

                // Stats grid
                _StatsGrid(progress: progress),
                const SizedBox(height: 14),

                // Rarity breakdown bar
                _RarityBreakdownBar(progress: progress),
                const SizedBox(height: 12),

                // Trait completion ring
                _TraitCompletionRow(progress: progress),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Cover background painter
// =============================================================================

/// Paints a subtle gradient background with faint radial glow and
/// a barely visible grid texture.
class _CoverBackgroundPainter extends CustomPainter {
  final bool isDark;
  final Color accentColor;

  _CoverBackgroundPainter({required this.isDark, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base fill.
    final basePaint = Paint()
      ..color = isDark ? const Color(0xFF181D28) : const Color(0xFFF0F2F5);
    canvas.drawRect(rect, basePaint);

    // Subtle radial glow from top-right corner.
    final glowCenter = Offset(size.width * 0.85, size.height * 0.15);
    final glowRadius = size.width * 0.6;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (glowCenter.dx / size.width) * 2 - 1,
          (glowCenter.dy / size.height) * 2 - 1,
        ),
        radius: glowRadius / math.max(size.width, size.height),
        colors: [
          accentColor.withValues(alpha: isDark ? 0.06 : 0.04),
          accentColor.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, glowPaint);

    // Faint diagonal lines (subtle grid texture).
    final linePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.015)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 24.0;
    for (double d = -size.height; d < size.width + size.height; d += spacing) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height, size.height),
        linePaint,
      );
    }

    // Bottom edge fade.
    final edgePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          accentColor.withValues(alpha: isDark ? 0.04 : 0.02),
        ],
        stops: const [0.6, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, edgePaint);
  }

  @override
  bool shouldRepaint(_CoverBackgroundPainter oldDelegate) {
    return isDark != oldDelegate.isDark ||
        accentColor != oldDelegate.accentColor;
  }
}

// =============================================================================
// Explorer title section
// =============================================================================

/// Displays the explorer title emblem, title text, and subtitle.
class _ExplorerTitleSection extends StatelessWidget {
  final CollectionProgress progress;

  const _ExplorerTitleSection({required this.progress});

  @override
  Widget build(BuildContext context) {
    final title = progress.explorerTitle;
    final highestRarity = progress.highestRarity;

    return Column(
      children: [
        // Emblem
        _ExplorerEmblem(title: title, accentColor: highestRarity.borderColor),
        const SizedBox(height: 10),

        // Title
        Text(
          title.displayLabel.toUpperCase(),
          style: TextStyle(
            fontSize: AlbumConstants.coverTitleSize,
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
            letterSpacing: 2.0,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),

        // Subtitle
        Text(
          title.description,
          style: TextStyle(
            fontSize: AlbumConstants.coverSubtitleSize,
            color: context.textSecondary,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// =============================================================================
// Explorer emblem
// =============================================================================

/// A circular emblem icon representing the explorer title tier.
///
/// The emblem uses a radial gradient background colored by the highest
/// rarity achieved, with an icon inside that reflects the explorer rank.
class _ExplorerEmblem extends StatelessWidget {
  final ExplorerTitle title;
  final Color accentColor;

  const _ExplorerEmblem({required this.title, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AlbumConstants.coverEmblemSize,
      height: AlbumConstants.coverEmblemSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accentColor.withValues(alpha: 0.2),
            accentColor.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.15),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        _iconFor(title),
        size: AlbumConstants.coverEmblemSize * 0.45,
        color: accentColor.withValues(alpha: 0.85),
      ),
    );
  }

  IconData _iconFor(ExplorerTitle title) {
    return switch (title) {
      ExplorerTitle.newcomer => Icons.fiber_new_outlined,
      ExplorerTitle.observer => Icons.visibility_outlined,
      ExplorerTitle.explorer => Icons.explore_outlined,
      ExplorerTitle.cartographer => Icons.map_outlined,
      ExplorerTitle.signalHunter => Icons.cell_tower_outlined,
      ExplorerTitle.meshVeteran => Icons.military_tech_outlined,
      ExplorerTitle.meshCartographer => Icons.public_outlined,
      ExplorerTitle.longRangeRecordHolder => Icons.radar_outlined,
    };
  }
}

// =============================================================================
// Cover divider
// =============================================================================

/// A decorative horizontal divider with diamond center ornament.
class _CoverDivider extends StatelessWidget {
  final Color color;

  const _CoverDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 8,
      child: CustomPaint(
        painter: _CoverDividerPainter(color: color.withValues(alpha: 0.25)),
        size: const Size(double.infinity, 8),
      ),
    );
  }
}

class _CoverDividerPainter extends CustomPainter {
  final Color color;

  _CoverDividerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cy = size.height / 2;
    final center = size.width / 2;
    final diamondSize = 3.0;
    final lineGap = diamondSize + 4;

    // Left line (gradient fade-in).
    final leftGradient = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.0), color],
      ).createShader(Rect.fromLTRB(0, cy, center - lineGap, cy));
    leftGradient.strokeWidth = 0.75;
    leftGradient.style = PaintingStyle.stroke;
    canvas.drawLine(Offset(16, cy), Offset(center - lineGap, cy), leftGradient);

    // Right line (gradient fade-out).
    final rightGradient = Paint()
      ..shader = LinearGradient(
        colors: [color, color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTRB(center + lineGap, cy, size.width, cy));
    rightGradient.strokeWidth = 0.75;
    rightGradient.style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(center + lineGap, cy),
      Offset(size.width - 16, cy),
      rightGradient,
    );

    // Center diamond.
    final diamond = Path()
      ..moveTo(center - diamondSize, cy)
      ..lineTo(center, cy - diamondSize)
      ..lineTo(center + diamondSize, cy)
      ..lineTo(center, cy + diamondSize)
      ..close();
    canvas.drawPath(diamond, paint..style = PaintingStyle.fill);

    // Small dots flanking the diamond.
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(Offset(center - diamondSize - 6, cy), 1.0, dotPaint);
    canvas.drawCircle(Offset(center + diamondSize + 6, cy), 1.0, dotPaint);
  }

  @override
  bool shouldRepaint(_CoverDividerPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

// =============================================================================
// Stats grid
// =============================================================================

/// A 4-column grid of key collection metrics.
class _StatsGrid extends StatelessWidget {
  final CollectionProgress progress;

  const _StatsGrid({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCell(
            value: _compactNumber(progress.totalNodes),
            label: 'NODES',
            icon: Icons.hexagon_outlined,
          ),
        ),
        _VerticalDot(color: context.border),
        Expanded(
          child: _StatCell(
            value: _compactNumber(progress.totalEncounters),
            label: 'ENCOUNTERS',
            icon: Icons.remove_red_eye_outlined,
          ),
        ),
        _VerticalDot(color: context.border),
        Expanded(
          child: _StatCell(
            value: '${progress.totalRegions}',
            label: 'REGIONS',
            icon: Icons.map_outlined,
          ),
        ),
        _VerticalDot(color: context.border),
        Expanded(
          child: _StatCell(
            value: '${progress.daysExploring}',
            label: 'DAYS',
            icon: Icons.calendar_today_outlined,
          ),
        ),
      ],
    );
  }

  String _compactNumber(int n) {
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}k';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

/// A single metric cell in the stats grid.
class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatCell({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 14,
          color: context.textTertiary.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: AlbumConstants.coverStatValueSize,
            fontWeight: FontWeight.w800,
            fontFamily: AppTheme.fontFamily,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: AlbumConstants.coverStatLabelSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: context.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// A small centered dot used as a visual separator between stat cells.
class _VerticalDot extends StatelessWidget {
  final Color color;

  const _VerticalDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
    );
  }
}

// =============================================================================
// Rarity breakdown bar
// =============================================================================

/// A proportional stacked bar showing the distribution of card rarities.
///
/// Each rarity tier is rendered as a colored segment whose width is
/// proportional to the count of cards at that tier. A legend row
/// below shows the rarity labels and counts.
class _RarityBreakdownBar extends StatelessWidget {
  final CollectionProgress progress;

  const _RarityBreakdownBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final total = progress.totalNodes;
    if (total == 0) return const SizedBox.shrink();

    // Order: common first (leftmost) through legendary (rightmost).
    final orderedRarities = [
      CardRarity.common,
      CardRarity.uncommon,
      CardRarity.rare,
      CardRarity.epic,
      CardRarity.legendary,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stacked bar
        ClipRRect(
          borderRadius: BorderRadius.circular(
            AlbumConstants.coverRarityBarHeight / 2,
          ),
          child: SizedBox(
            height: AlbumConstants.coverRarityBarHeight,
            child: Row(
              children: orderedRarities.map((rarity) {
                final count = progress.rarityBreakdown[rarity] ?? 0;
                if (count == 0) return const SizedBox.shrink();
                final fraction = count / total;

                return Flexible(
                  flex: (fraction * 1000).round().clamp(1, 1000),
                  child: Container(color: rarity.borderColor),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Legend row
        Wrap(
          spacing: 12,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: orderedRarities.map((rarity) {
            final count = progress.rarityBreakdown[rarity] ?? 0;
            if (count == 0) return const SizedBox.shrink();

            return _RarityLegendItem(rarity: rarity, count: count);
          }).toList(),
        ),
      ],
    );
  }
}

/// A single legend item showing a colored dot, rarity label, and count.
class _RarityLegendItem extends StatelessWidget {
  final CardRarity rarity;
  final int count;

  const _RarityLegendItem({required this.rarity, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AlbumConstants.coverRarityDotSize,
          height: AlbumConstants.coverRarityDotSize,
          decoration: BoxDecoration(
            color: rarity.borderColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          rarity.label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: rarity.borderColor.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            fontFamily: AppTheme.fontFamily,
            color: context.textSecondary,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Trait completion row
// =============================================================================

/// A horizontal row of dots representing trait completion.
///
/// Each known trait type gets a dot. Filled dots (with trait color) indicate
/// that at least one node of that trait has been discovered. Unfilled dots
/// represent traits not yet seen. A label shows the completion fraction.
class _TraitCompletionRow extends StatelessWidget {
  final CollectionProgress progress;

  const _TraitCompletionRow({required this.progress});

  @override
  Widget build(BuildContext context) {
    final knownTraits = NodeTrait.values
        .where((t) => t != NodeTrait.unknown)
        .toList();
    final completionPercent = (progress.traitCompletionFraction * 100).round();

    return Column(
      children: [
        // Label
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TRAIT COLLECTION',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: context.textTertiary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$completionPercent%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                fontFamily: AppTheme.fontFamily,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Trait dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: knownTraits.map((trait) {
            final count = progress.traitBreakdown[trait] ?? 0;
            final discovered = count > 0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Tooltip(
                message:
                    '${trait.displayLabel}${discovered ? ' ($count)' : ''}',
                child: Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: discovered
                            ? trait.color
                            : context.border.withValues(alpha: 0.2),
                        border: Border.all(
                          color: discovered
                              ? trait.color.withValues(alpha: 0.5)
                              : context.border.withValues(alpha: 0.15),
                          width: 1,
                        ),
                        boxShadow: discovered
                            ? [
                                BoxShadow(
                                  color: trait.color.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  spreadRadius: 0.5,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      trait.displayLabel
                          .substring(0, math.min(3, trait.displayLabel.length))
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 6,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: discovered
                            ? trait.color.withValues(alpha: 0.7)
                            : context.textTertiary.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
