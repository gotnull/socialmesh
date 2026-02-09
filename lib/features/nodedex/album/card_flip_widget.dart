// SPDX-License-Identifier: GPL-3.0-or-later

// Card Flip Widget — 3D Y-axis flip animation for collectible cards.
//
// Provides a smooth 3D rotation around the vertical axis to reveal
// a card's back side. The front shows the full SigilCard; the back
// shows a stats summary with encounter data, patina breakdown, and
// trait evidence.
//
// Visual design:
//   - Perspective-correct 3D rotation (matrix4 with perspective)
//   - Front face hidden when angle > 90 degrees (and vice versa)
//   - Rarity-appropriate border maintained on both sides
//   - Back side uses the same card dimensions and border radius
//   - Subtle shadow depth shift during rotation
//
// Interaction:
//   - Tap to flip (toggled via CardFlipStateNotifier)
//   - Animation respects reduce-motion (instant swap when enabled)
//   - Widget is stateful to own its AnimationController
//
// Performance:
//   - Single AnimationController per card
//   - No rebuilds during animation — uses AnimatedBuilder
//   - Transform applied via Matrix4, not multiple nested transforms

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../models/nodedex_entry.dart';
import '../services/patina_score.dart';
import '../services/trait_engine.dart';
import '../widgets/sigil_card.dart';
import 'album_constants.dart';
import 'album_providers.dart';

/// A card that flips between front (SigilCard) and back (stats) on tap.
///
/// The flip state is managed externally via [cardFlipStateProvider] so
/// that flip state persists across rebuilds and can be reset globally
/// when the gallery is closed.
///
/// Usage:
/// ```dart
/// CardFlipWidget(
///   entry: entry,
///   traitResult: traitResult,
///   patinaResult: patinaResult,
///   displayName: 'Node Alpha',
///   hexId: '!A1B2',
///   width: 320,
///   front: SigilCard(...),
/// )
/// ```
class CardFlipWidget extends ConsumerStatefulWidget {
  /// The NodeDex entry for this card.
  final NodeDexEntry entry;

  /// Inferred trait result for stats display.
  final TraitResult? traitResult;

  /// Computed patina result for the back side breakdown.
  final PatinaResult? patinaResult;

  /// Display name shown on the back.
  final String displayName;

  /// Hex ID shown on the back.
  final String hexId;

  /// Card width. Height is derived from 5:7 aspect ratio.
  final double width;

  /// The front face widget (typically a SigilCard).
  final Widget front;

  /// Whether to animate the flip. Set false for reduce-motion.
  final bool animate;

  const CardFlipWidget({
    super.key,
    required this.entry,
    required this.traitResult,
    this.patinaResult,
    required this.displayName,
    required this.hexId,
    required this.width,
    required this.front,
    this.animate = true,
  });

  @override
  ConsumerState<CardFlipWidget> createState() => _CardFlipWidgetState();
}

class _CardFlipWidgetState extends ConsumerState<CardFlipWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  /// Whether we are currently showing the back side.
  bool _showingBack = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AlbumConstants.flipDuration,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: AlbumConstants.flipCurve,
    );

    // Sync initial state from provider.
    final flipped = ref.read(cardFlipStateProvider);
    _showingBack = flipped.contains(widget.entry.nodeNum);
    if (_showingBack) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    ref.read(cardFlipStateProvider.notifier).toggleFlip(widget.entry.nodeNum);

    if (!widget.animate) {
      // Instant swap for reduce-motion.
      setState(() {
        _showingBack = !_showingBack;
        _controller.value = _showingBack ? 1.0 : 0.0;
      });
      return;
    }

    if (_showingBack) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    _showingBack = !_showingBack;
  }

  @override
  Widget build(BuildContext context) {
    // Watch flip state to stay in sync with external resets.
    final flippedSet = ref.watch(cardFlipStateProvider);
    final shouldBeFlipped = flippedSet.contains(widget.entry.nodeNum);

    // Sync if externally changed (e.g. resetAll).
    if (shouldBeFlipped != _showingBack) {
      _showingBack = shouldBeFlipped;
      if (widget.animate) {
        if (_showingBack) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      } else {
        _controller.value = _showingBack ? 1.0 : 0.0;
      }
    }

    final height = widget.width * 1.4;

    return GestureDetector(
      onTap: _handleTap,
      child: SizedBox(
        width: widget.width,
        height: height,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final angle = _animation.value * math.pi;
            final showBack = angle > math.pi / 2;

            // Build the transform matrix with perspective.
            final transform = Matrix4.identity()
              ..setEntry(3, 2, AlbumConstants.flipPerspective)
              ..rotateY(angle);

            // For the back side, counter-rotate so text is not mirrored.
            final backTransform = Matrix4.identity()
              ..setEntry(3, 2, AlbumConstants.flipPerspective)
              ..rotateY(angle - math.pi);

            return Transform(
              transform: showBack ? backTransform : transform,
              alignment: Alignment.center,
              child: showBack
                  ? _CardBack(
                      entry: widget.entry,
                      traitResult: widget.traitResult,
                      patinaResult: widget.patinaResult,
                      displayName: widget.displayName,
                      hexId: widget.hexId,
                      width: widget.width,
                      height: height,
                    )
                  : widget.front,
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Card Back — stats summary
// =============================================================================

/// The back face of a collectible card showing stats and patina breakdown.
///
/// Renders at the same dimensions as the front (SigilCard) with a matching
/// rarity border. Content is organized into compact sections:
///   - Header with name and hex ID
///   - Encounter statistics
///   - Patina breakdown axes
///   - Trait classification with confidence
///   - Region history summary
///   - Co-seen node count
class _CardBack extends StatelessWidget {
  final NodeDexEntry entry;
  final TraitResult? traitResult;
  final PatinaResult? patinaResult;
  final String displayName;
  final String hexId;
  final double width;
  final double height;

  const _CardBack({
    required this.entry,
    required this.traitResult,
    this.patinaResult,
    required this.displayName,
    required this.hexId,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTrait =
        traitResult ??
        const TraitResult(primary: NodeTrait.unknown, confidence: 0.0);
    final rarity = CardRarityVisuals.fromNodeData(
      encounterCount: entry.encounterCount,
      trait: effectiveTrait.primary,
    );

    final scale = width / 320.0;
    final traitColor = effectiveTrait.primary.color;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? const Color(0xFF1A1F2E)
            : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(AlbumConstants.slotBorderRadius),
        border: Border.all(
          color: rarity.borderColor,
          width: rarity.borderWidth,
        ),
        boxShadow: rarity.hasGlow
            ? [
                BoxShadow(
                  color: rarity.glowColor.withValues(alpha: 0.3),
                  blurRadius: rarity.glowBlur,
                  spreadRadius: rarity.glowSpread,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          AlbumConstants.slotBorderRadius - rarity.borderWidth,
        ),
        child: Padding(
          padding: EdgeInsets.all(12.0 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _BackHeader(
                displayName: displayName,
                hexId: hexId,
                rarity: rarity,
                traitColor: traitColor,
                scale: scale,
              ),
              SizedBox(height: 8.0 * scale),

              // Divider
              _OrnamentLine(color: rarity.borderColor, scale: scale),
              SizedBox(height: 8.0 * scale),

              // Encounter stats
              _StatsSection(entry: entry, scale: scale),
              SizedBox(height: 6.0 * scale),

              // Trait classification
              _TraitSection(traitResult: effectiveTrait, scale: scale),
              SizedBox(height: 6.0 * scale),

              // Patina breakdown (if available)
              if (patinaResult != null) ...[
                _PatinaSection(
                  result: patinaResult!,
                  accentColor: traitColor,
                  scale: scale,
                ),
                SizedBox(height: 6.0 * scale),
              ],

              const Spacer(),

              // Region and co-seen summary
              _BottomSummary(entry: entry, rarity: rarity, scale: scale),

              SizedBox(height: 4.0 * scale),

              // Footer
              _BackFooter(rarity: rarity, scale: scale),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Back card sub-sections
// =============================================================================

class _BackHeader extends StatelessWidget {
  final String displayName;
  final String hexId;
  final CardRarity rarity;
  final Color traitColor;
  final double scale;

  const _BackHeader({
    required this.displayName,
    required this.hexId,
    required this.rarity,
    required this.traitColor,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          displayName,
          style: TextStyle(
            fontSize: 16.0 * scale,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
            letterSpacing: 0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 2.0 * scale),
        Text(
          hexId,
          style: TextStyle(
            fontSize: 10.0 * scale,
            fontWeight: FontWeight.w500,
            fontFamily: AppTheme.fontFamily,
            color: traitColor.withValues(alpha: 0.7),
            letterSpacing: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 2.0 * scale),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 8.0 * scale,
            vertical: 2.0 * scale,
          ),
          decoration: BoxDecoration(
            color: rarity.borderColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4.0 * scale),
          ),
          child: Text(
            rarity.label,
            style: TextStyle(
              fontSize: 8.0 * scale,
              fontWeight: FontWeight.w800,
              color: rarity.borderColor,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrnamentLine extends StatelessWidget {
  final Color color;
  final double scale;

  const _OrnamentLine({required this.color, required this.scale});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3.0 * scale,
      child: CustomPaint(
        painter: _OrnamentLinePainter(color: color, scale: scale),
        size: Size.infinite,
      ),
    );
  }
}

class _OrnamentLinePainter extends CustomPainter {
  final Color color;
  final double scale;

  _OrnamentLinePainter({required this.color, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 0.5 * scale
      ..style = PaintingStyle.stroke;

    final y = size.height / 2;
    final dotSize = 2.0 * scale;
    final margin = 20.0 * scale;

    // Left line
    canvas.drawLine(Offset(0, y), Offset(margin, y), paint);
    // Center diamond
    final center = size.width / 2;
    final path = Path()
      ..moveTo(center - dotSize, y)
      ..lineTo(center, y - dotSize)
      ..lineTo(center + dotSize, y)
      ..lineTo(center, y + dotSize)
      ..close();
    canvas.drawPath(path, paint..style = PaintingStyle.fill);
    paint.style = PaintingStyle.stroke;
    // Right line
    canvas.drawLine(
      Offset(size.width - margin, y),
      Offset(size.width, y),
      paint,
    );
  }

  @override
  bool shouldRepaint(_OrnamentLinePainter oldDelegate) => false;
}

class _StatsSection extends StatelessWidget {
  final NodeDexEntry entry;
  final double scale;

  const _StatsSection({required this.entry, required this.scale});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'ENCOUNTER LOG', scale: scale),
        SizedBox(height: 4.0 * scale),
        _StatRow(
          label: 'Encounters',
          value: '${entry.encounterCount}',
          scale: scale,
        ),
        _StatRow(
          label: 'Messages',
          value: '${entry.messageCount}',
          scale: scale,
        ),
        _StatRow(
          label: 'First Seen',
          value: dateFormat.format(entry.firstSeen),
          scale: scale,
        ),
        _StatRow(
          label: 'Last Seen',
          value: dateFormat.format(entry.lastSeen),
          scale: scale,
        ),
        if (entry.maxDistanceSeen != null && entry.maxDistanceSeen! > 0)
          _StatRow(
            label: 'Max Distance',
            value: _formatDistance(entry.maxDistanceSeen!),
            scale: scale,
          ),
        if (entry.bestSnr != null)
          _StatRow(
            label: 'Best SNR',
            value: '${entry.bestSnr} dB',
            scale: scale,
          ),
      ],
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }
}

class _TraitSection extends StatelessWidget {
  final TraitResult traitResult;
  final double scale;

  const _TraitSection({required this.traitResult, required this.scale});

  @override
  Widget build(BuildContext context) {
    final confidence = (traitResult.confidence * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'CLASSIFICATION', scale: scale),
        SizedBox(height: 4.0 * scale),
        Row(
          children: [
            Container(
              width: 6.0 * scale,
              height: 6.0 * scale,
              decoration: BoxDecoration(
                color: traitResult.primary.color,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 6.0 * scale),
            Expanded(
              child: Text(
                traitResult.primary.displayLabel,
                style: TextStyle(
                  fontSize: 11.0 * scale,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ),
            Text(
              '$confidence%',
              style: TextStyle(
                fontSize: 10.0 * scale,
                fontWeight: FontWeight.w700,
                fontFamily: AppTheme.fontFamily,
                color: traitResult.primary.color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        if (traitResult.secondary != null) ...[
          SizedBox(height: 2.0 * scale),
          Row(
            children: [
              SizedBox(width: 12.0 * scale),
              Container(
                width: 4.0 * scale,
                height: 4.0 * scale,
                decoration: BoxDecoration(
                  color: traitResult.secondary!.color.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6.0 * scale),
              Text(
                traitResult.secondary!.displayLabel,
                style: TextStyle(
                  fontSize: 9.0 * scale,
                  color: context.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${((traitResult.secondaryConfidence ?? 0) * 100).round()}%',
                style: TextStyle(
                  fontSize: 9.0 * scale,
                  fontFamily: AppTheme.fontFamily,
                  color: context.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PatinaSection extends StatelessWidget {
  final PatinaResult result;
  final Color accentColor;
  final double scale;

  const _PatinaSection({
    required this.result,
    required this.accentColor,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionLabel(text: 'PATINA', scale: scale),
            const Spacer(),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 6.0 * scale,
                vertical: 1.0 * scale,
              ),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(3.0 * scale),
              ),
              child: Text(
                '${result.stampLabel}: ${result.score}',
                style: TextStyle(
                  fontSize: 8.0 * scale,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppTheme.fontFamily,
                  color: accentColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 4.0 * scale),
        _PatinaAxis(
          label: 'Tenure',
          value: result.tenure,
          color: accentColor,
          scale: scale,
        ),
        _PatinaAxis(
          label: 'Encounters',
          value: result.encounters,
          color: accentColor,
          scale: scale,
        ),
        _PatinaAxis(
          label: 'Reach',
          value: result.reach,
          color: accentColor,
          scale: scale,
        ),
        _PatinaAxis(
          label: 'Signal',
          value: result.signalDepth,
          color: accentColor,
          scale: scale,
        ),
        _PatinaAxis(
          label: 'Social',
          value: result.social,
          color: accentColor,
          scale: scale,
        ),
        _PatinaAxis(
          label: 'Recency',
          value: result.recency,
          color: accentColor,
          scale: scale,
        ),
      ],
    );
  }
}

class _PatinaAxis extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final double scale;

  const _PatinaAxis({
    required this.label,
    required this.value,
    required this.color,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.0 * scale),
      child: Row(
        children: [
          SizedBox(
            width: 56.0 * scale,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 8.0 * scale,
                color: context.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(1.0 * scale),
              child: SizedBox(
                height: 2.5 * scale,
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    return Stack(
                      children: [
                        Container(
                          width: constraints.maxWidth,
                          color: context.border.withValues(alpha: 0.2),
                        ),
                        Container(
                          width: constraints.maxWidth * value.clamp(0.0, 1.0),
                          color: color.withValues(alpha: 0.5),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          SizedBox(width: 4.0 * scale),
          SizedBox(
            width: 24.0 * scale,
            child: Text(
              '${(value * 100).round()}',
              style: TextStyle(
                fontSize: 7.0 * scale,
                fontWeight: FontWeight.w600,
                fontFamily: AppTheme.fontFamily,
                color: color.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomSummary extends StatelessWidget {
  final NodeDexEntry entry;
  final CardRarity rarity;
  final double scale;

  const _BottomSummary({
    required this.entry,
    required this.rarity,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CompactStat(
          icon: Icons.map_outlined,
          value: '${entry.regionCount}',
          label: 'Regions',
          color: rarity.borderColor,
          scale: scale,
        ),
        _CompactStat(
          icon: Icons.people_outline,
          value: '${entry.coSeenCount}',
          label: 'Co-seen',
          color: rarity.borderColor,
          scale: scale,
        ),
        _CompactStat(
          icon: Icons.calendar_today_outlined,
          value: '${entry.age.inDays}',
          label: 'Days',
          color: rarity.borderColor,
          scale: scale,
        ),
      ],
    );
  }
}

class _CompactStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final double scale;

  const _CompactStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 12.0 * scale, color: color.withValues(alpha: 0.5)),
        SizedBox(height: 2.0 * scale),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.0 * scale,
            fontWeight: FontWeight.w700,
            fontFamily: AppTheme.fontFamily,
            color: context.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 7.0 * scale,
            color: context.textTertiary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _BackFooter extends StatelessWidget {
  final CardRarity rarity;
  final double scale;

  const _BackFooter({required this.rarity, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.touch_app_outlined,
          size: 10.0 * scale,
          color: context.textTertiary.withValues(alpha: 0.4),
        ),
        SizedBox(width: 4.0 * scale),
        Text(
          'TAP TO FLIP',
          style: TextStyle(
            fontSize: 7.0 * scale,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: context.textTertiary.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Shared sub-widgets
// =============================================================================

class _SectionLabel extends StatelessWidget {
  final String text;
  final double scale;

  const _SectionLabel({required this.text, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 8.0 * scale,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: context.textTertiary.withValues(alpha: 0.6),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final double scale;

  const _StatRow({
    required this.label,
    required this.value,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.0 * scale),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9.0 * scale,
                color: context.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 9.0 * scale,
              fontWeight: FontWeight.w600,
              fontFamily: AppTheme.fontFamily,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
