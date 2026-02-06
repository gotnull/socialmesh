// SPDX-License-Identifier: GPL-3.0-or-later

// Sigil Card — premium collectible trading card for mesh node identity.
//
// A visually striking card showcasing a node's procedural identity:
// - Rarity-based ornate border with glow effects
// - Large dramatic sigil with layered glow
// - Dense, information-rich layout with no dead space
// - RPG-style stat grid with rarity-colored accents
// - Device info, palette strip, and branding footer
// - Proper dark background clipping for clean capture output
//
// Two render modes:
// 1. Live preview in bottom sheet (animated sigil)
// 2. Static capture via RepaintBoundary for PNG sharing

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../models/nodedex_entry.dart';
import '../services/sigil_generator.dart';
import '../services/trait_engine.dart';
import 'animated_sigil_container.dart';
import 'sigil_painter.dart';
import 'trait_badge.dart';

// =============================================================================
// Rarity system
// =============================================================================

/// Card rarity tier based on encounter count and trait classification.
///
/// Rarity determines the border color, glow intensity, and decorative
/// elements on the card. Higher rarity = more visual flair.
enum CardRarity {
  /// Unknown trait or fewer than 5 encounters.
  common,

  /// Known trait with 5-19 encounters.
  uncommon,

  /// 20-49 encounters.
  rare,

  /// 50-99 encounters.
  epic,

  /// 100+ encounters.
  legendary,
}

/// Visual properties for each rarity tier.
extension CardRarityVisuals on CardRarity {
  String get label {
    return switch (this) {
      CardRarity.common => 'COMMON',
      CardRarity.uncommon => 'UNCOMMON',
      CardRarity.rare => 'RARE',
      CardRarity.epic => 'EPIC',
      CardRarity.legendary => 'LEGENDARY',
    };
  }

  Color get borderColor {
    return switch (this) {
      CardRarity.common => const Color(0xFF6B7280),
      CardRarity.uncommon => const Color(0xFF10B981),
      CardRarity.rare => const Color(0xFF3B82F6),
      CardRarity.epic => const Color(0xFF8B5CF6),
      CardRarity.legendary => const Color(0xFFD4AF37),
    };
  }

  Color get glowColor {
    return switch (this) {
      CardRarity.common => const Color(0xFF6B7280),
      CardRarity.uncommon => const Color(0xFF10B981),
      CardRarity.rare => const Color(0xFF3B82F6),
      CardRarity.epic => const Color(0xFF8B5CF6),
      CardRarity.legendary => const Color(0xFFFFCC00),
    };
  }

  double get borderWidth {
    return switch (this) {
      CardRarity.common => 1.5,
      CardRarity.uncommon => 1.5,
      CardRarity.rare => 2.0,
      CardRarity.epic => 2.5,
      CardRarity.legendary => 3.0,
    };
  }

  bool get hasGlow => this == CardRarity.epic || this == CardRarity.legendary;

  double get glowSpread {
    return switch (this) {
      CardRarity.epic => 4.0,
      CardRarity.legendary => 8.0,
      _ => 0.0,
    };
  }

  double get glowBlur {
    return switch (this) {
      CardRarity.epic => 12.0,
      CardRarity.legendary => 20.0,
      _ => 0.0,
    };
  }

  /// Secondary accent for multi-tone borders on higher rarities.
  Color get secondaryBorderColor {
    return switch (this) {
      CardRarity.legendary => const Color(0xFFFFE082),
      CardRarity.epic => const Color(0xFFB388FF),
      _ => borderColor,
    };
  }

  /// Compute rarity from node data.
  static CardRarity fromNodeData({
    required int encounterCount,
    required NodeTrait trait,
  }) {
    if (encounterCount >= 100) return CardRarity.legendary;
    if (encounterCount >= 50) return CardRarity.epic;
    if (encounterCount >= 20) return CardRarity.rare;
    if (encounterCount >= 5 && trait != NodeTrait.unknown) {
      return CardRarity.uncommon;
    }
    return CardRarity.common;
  }
}

// =============================================================================
// Sigil Card Widget
// =============================================================================

/// A premium collectible trading card for a mesh node.
///
/// Renders at a fixed portrait aspect ratio (~5:7) suitable for
/// image capture and sharing. The card is fully self-contained.
///
/// Set [animated] to false for static image capture (RepaintBoundary).
/// Set it to true for the live preview in the bottom sheet.
class SigilCard extends StatelessWidget {
  /// Node number for sigil generation.
  final int nodeNum;

  /// Pre-computed sigil data. Generated from [nodeNum] if null.
  final SigilData? sigil;

  /// Display name of the node.
  final String displayName;

  /// Hex ID string (e.g. "!aBcDeF12").
  final String hexId;

  /// Inferred trait result.
  final TraitResult traitResult;

  /// NodeDex entry with stats.
  final NodeDexEntry entry;

  /// Hardware model string (e.g. "HELTEC V3"). Null if unknown.
  final String? hardwareModel;

  /// Firmware version string. Null if unknown.
  final String? firmwareVersion;

  /// Node role string (e.g. "ROUTER"). Null if unknown.
  final String? role;

  /// Whether to animate the sigil (false for image capture).
  final bool animated;

  /// Card width. Height is derived from the 5:7 aspect ratio.
  final double width;

  const SigilCard({
    super.key,
    required this.nodeNum,
    this.sigil,
    required this.displayName,
    required this.hexId,
    required this.traitResult,
    required this.entry,
    this.hardwareModel,
    this.firmwareVersion,
    this.role,
    this.animated = true,
    this.width = 320,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSigil = sigil ?? SigilGenerator.generate(nodeNum);
    final rarity = CardRarityVisuals.fromNodeData(
      encounterCount: entry.encounterCount,
      trait: traitResult.primary,
    );
    final height = width * 1.4; // 5:7 aspect ratio

    return SizedBox(
      width: width,
      height: height,
      child: _CardBody(
        width: width,
        height: height,
        sigil: effectiveSigil,
        nodeNum: nodeNum,
        displayName: displayName,
        hexId: hexId,
        traitResult: traitResult,
        entry: entry,
        rarity: rarity,
        hardwareModel: hardwareModel,
        firmwareVersion: firmwareVersion,
        role: role,
        animated: animated,
      ),
    );
  }
}

// =============================================================================
// Card body — the full card layout
// =============================================================================

class _CardBody extends StatelessWidget {
  final double width;
  final double height;
  final SigilData sigil;
  final int nodeNum;
  final String displayName;
  final String hexId;
  final TraitResult traitResult;
  final NodeDexEntry entry;
  final CardRarity rarity;
  final String? hardwareModel;
  final String? firmwareVersion;
  final String? role;
  final bool animated;

  const _CardBody({
    required this.width,
    required this.height,
    required this.sigil,
    required this.nodeNum,
    required this.displayName,
    required this.hexId,
    required this.traitResult,
    required this.entry,
    required this.rarity,
    this.hardwareModel,
    this.firmwareVersion,
    this.role,
    required this.animated,
  });

  @override
  Widget build(BuildContext context) {
    final s = width / 320.0;
    final borderRadius = BorderRadius.circular(14 * s);

    // The outermost container paints a solid dark background behind
    // everything so captured PNGs never show transparent corners.
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: borderRadius,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: rarity.borderColor,
            width: rarity.borderWidth * s,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16 * s,
              offset: Offset(0, 6 * s),
            ),
            if (rarity.hasGlow)
              BoxShadow(
                color: rarity.glowColor.withValues(alpha: 0.35),
                blurRadius: rarity.glowBlur * s,
                spreadRadius: rarity.glowSpread * s,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            children: [
              // Layer 0: deep dark base
              Positioned.fill(child: Container(color: const Color(0xFF0D1117))),

              // Layer 1: radial gradient from sigil color
              Positioned.fill(
                child: CustomPaint(
                  painter: _CardBackgroundPainter(
                    primaryColor: sigil.primaryColor,
                    secondaryColor: sigil.secondaryColor,
                    traitColor: traitResult.primary.color,
                    rarityColor: rarity.borderColor,
                    scale: s,
                  ),
                ),
              ),

              // Layer 2: content
              Column(
                children: [
                  // Trait banner at top
                  _TraitBanner(
                    trait: traitResult.primary,
                    rarity: rarity,
                    role: role,
                    scale: s,
                  ),

                  // Sigil hero area — large and dramatic
                  Expanded(
                    flex: 9,
                    child: _SigilHero(
                      sigil: sigil,
                      nodeNum: nodeNum,
                      trait: traitResult.primary,
                      rarity: rarity,
                      animated: animated,
                      scale: s,
                    ),
                  ),

                  // Name + hex ID
                  _NamePlate(
                    displayName: displayName,
                    hexId: hexId,
                    traitColor: traitResult.primary.color,
                    scale: s,
                  ),

                  // Ornament divider
                  _OrnamentDivider(color: rarity.borderColor, scale: s),

                  // Stats grid
                  Expanded(
                    flex: 5,
                    child: _StatsGrid(
                      entry: entry,
                      sigil: sigil,
                      rarity: rarity,
                      scale: s,
                    ),
                  ),

                  // Device info + palette
                  _DeviceAndPaletteLine(
                    sigil: sigil,
                    hardwareModel: hardwareModel,
                    firmwareVersion: firmwareVersion,
                    scale: s,
                  ),

                  // Brand footer
                  _BrandFooter(entry: entry, rarity: rarity, scale: s),
                ],
              ),

              // Layer 3: inner border highlight (subtle inset glow)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      border: Border.all(
                        color: rarity.borderColor.withValues(alpha: 0.08),
                        width: 1.0 * s,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          rarity.borderColor.withValues(alpha: 0.06),
                          Colors.transparent,
                          Colors.transparent,
                          rarity.borderColor.withValues(alpha: 0.03),
                        ],
                        stops: const [0.0, 0.15, 0.85, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Background painter — layered radial gradients for depth
// =============================================================================

class _CardBackgroundPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final Color traitColor;
  final Color rarityColor;
  final double scale;

  _CardBackgroundPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.traitColor,
    required this.rarityColor,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.32);

    // Primary radial: sigil color emanating from sigil position
    final primaryGradient = RadialGradient(
      center: Alignment(
        (center.dx / size.width) * 2 - 1,
        (center.dy / size.height) * 2 - 1,
      ),
      radius: 0.7,
      colors: [
        primaryColor.withValues(alpha: 0.15),
        primaryColor.withValues(alpha: 0.05),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = primaryGradient.createShader(Offset.zero & size),
    );

    // Secondary accent: subtle warm tone from bottom
    final secondaryGradient = RadialGradient(
      center: const Alignment(0.3, 1.2),
      radius: 0.8,
      colors: [secondaryColor.withValues(alpha: 0.06), Colors.transparent],
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = secondaryGradient.createShader(Offset.zero & size),
    );

    // Trait color accent from top corner
    final traitGradient = RadialGradient(
      center: const Alignment(-0.8, -1.0),
      radius: 0.6,
      colors: [traitColor.withValues(alpha: 0.06), Colors.transparent],
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = traitGradient.createShader(Offset.zero & size),
    );

    // Subtle vertical edge vignette for depth
    final vignettePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withValues(alpha: 0.15),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: 0.15),
        ],
        stops: const [0.0, 0.12, 0.88, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, vignettePaint);
  }

  @override
  bool shouldRepaint(_CardBackgroundPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.traitColor != traitColor;
  }
}

// =============================================================================
// Trait banner — top header with trait + role
// =============================================================================

class _TraitBanner extends StatelessWidget {
  final NodeTrait trait;
  final CardRarity rarity;
  final String? role;
  final double scale;

  const _TraitBanner({
    required this.trait,
    required this.rarity,
    this.role,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final traitColor = trait.color;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 7 * scale,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            traitColor.withValues(alpha: 0.2),
            traitColor.withValues(alpha: 0.06),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        border: Border(
          bottom: BorderSide(
            color: traitColor.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Trait icon
          TraitIcon(trait: trait, size: 13 * scale),
          SizedBox(width: 5 * scale),

          // Trait name
          Text(
            trait.displayLabel.toUpperCase(),
            style: TextStyle(
              fontSize: 12 * scale,
              fontWeight: FontWeight.w800,
              color: traitColor,
              letterSpacing: 2.5 * scale,
              fontFamily: AppTheme.fontFamily,
            ),
          ),

          // Role badge
          if (role != null && role!.isNotEmpty) ...[
            SizedBox(width: 8 * scale),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 6 * scale,
                vertical: 2 * scale,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(4 * scale),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Text(
                role!,
                style: TextStyle(
                  fontSize: 7.5 * scale,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 0.5 * scale,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Sigil hero — large dramatic sigil display
// =============================================================================

class _SigilHero extends StatelessWidget {
  final SigilData sigil;
  final int nodeNum;
  final NodeTrait trait;
  final CardRarity rarity;
  final bool animated;
  final double scale;

  const _SigilHero({
    required this.sigil,
    required this.nodeNum,
    required this.trait,
    required this.rarity,
    required this.animated,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    // Sigil takes up most of the hero area for maximum visual impact
    final sigilSize = 120.0 * scale;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer atmospheric glow ring
        Container(
          width: sigilSize * 1.5,
          height: sigilSize * 1.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                sigil.primaryColor.withValues(alpha: 0.08),
                sigil.primaryColor.withValues(alpha: 0.02),
                Colors.transparent,
              ],
              stops: const [0.3, 0.7, 1.0],
            ),
          ),
        ),

        // Rarity ring (subtle orbit line)
        if (rarity.index >= CardRarity.rare.index)
          CustomPaint(
            size: Size(sigilSize * 1.35, sigilSize * 1.35),
            painter: _OrbitRingPainter(color: rarity.borderColor, scale: scale),
          ),

        // The sigil itself
        animated
            ? AnimatedSigilContainer(
                sigil: sigil,
                nodeNum: nodeNum,
                size: sigilSize,
                mode: SigilAnimationMode.ambientOnly,
                showGlow: true,
                showTracer: false,
                trait: trait,
              )
            : SigilDisplay(
                sigil: sigil,
                nodeNum: nodeNum,
                size: sigilSize,
                showGlow: true,
                trait: trait,
              ),
      ],
    );
  }
}

// =============================================================================
// Orbit ring painter — decorative ring around sigil for rare+ cards
// =============================================================================

class _OrbitRingPainter extends CustomPainter {
  final Color color;
  final double scale;

  _OrbitRingPainter({required this.color, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Dashed circle effect
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * scale;

    const segments = 60;
    const gapRatio = 0.3;

    for (int i = 0; i < segments; i++) {
      final startAngle = (i / segments) * 2 * math.pi;
      final sweepAngle = ((1 - gapRatio) / segments) * 2 * math.pi;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }

    // Small diamond markers at cardinal points
    final markerPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * 2 * math.pi - math.pi / 2;
      final pos = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final ds = 2.0 * scale;
      final path = Path()
        ..moveTo(pos.dx, pos.dy - ds)
        ..lineTo(pos.dx + ds, pos.dy)
        ..lineTo(pos.dx, pos.dy + ds)
        ..lineTo(pos.dx - ds, pos.dy)
        ..close();
      canvas.drawPath(path, markerPaint);
    }
  }

  @override
  bool shouldRepaint(_OrbitRingPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.scale != scale;
  }
}

// =============================================================================
// Name plate — node name and hex ID
// =============================================================================

class _NamePlate extends StatelessWidget {
  final String displayName;
  final String hexId;
  final Color traitColor;
  final double scale;

  const _NamePlate({
    required this.displayName,
    required this.hexId,
    required this.traitColor,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16 * scale, 0, 16 * scale, 2 * scale),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Display name — bold and prominent
          Text(
            displayName,
            style: TextStyle(
              fontSize: 20 * scale,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 3 * scale),
          // Hex ID in mono
          Text(
            hexId,
            style: TextStyle(
              fontSize: 10 * scale,
              fontWeight: FontWeight.w500,
              color: traitColor.withValues(alpha: 0.6),
              fontFamily: AppTheme.fontFamily,
              letterSpacing: 1.5 * scale,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Ornament divider
// =============================================================================

class _OrnamentDivider extends StatelessWidget {
  final Color color;
  final double scale;

  const _OrnamentDivider({required this.color, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 20 * scale,
        vertical: 5 * scale,
      ),
      child: CustomPaint(
        size: Size(double.infinity, 8 * scale),
        painter: _OrnamentDividerPainter(color: color, scale: scale),
      ),
    );
  }
}

class _OrnamentDividerPainter extends CustomPainter {
  final Color color;
  final double scale;

  _OrnamentDividerPainter({required this.color, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final midX = size.width / 2;
    final diamondSize = 3.5 * scale;

    // Gradient lines from center outward
    final leftPaint = Paint()
      ..shader =
          LinearGradient(
            colors: [
              color.withValues(alpha: 0.0),
              color.withValues(alpha: 0.35),
            ],
          ).createShader(
            Rect.fromLTRB(0, midY, midX - diamondSize - 8 * scale, midY),
          )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 * scale
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, midY),
      Offset(midX - diamondSize - 8 * scale, midY),
      leftPaint,
    );

    final rightPaint = Paint()
      ..shader =
          LinearGradient(
            colors: [
              color.withValues(alpha: 0.35),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromLTRB(
              midX + diamondSize + 8 * scale,
              midY,
              size.width,
              midY,
            ),
          )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 * scale
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(midX + diamondSize + 8 * scale, midY),
      Offset(size.width, midY),
      rightPaint,
    );

    // Center diamond
    final diamondPath = Path()
      ..moveTo(midX, midY - diamondSize)
      ..lineTo(midX + diamondSize, midY)
      ..lineTo(midX, midY + diamondSize)
      ..lineTo(midX - diamondSize, midY)
      ..close();

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawPath(diamondPath, fillPaint);

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 * scale;

    canvas.drawPath(diamondPath, borderPaint);
  }

  @override
  bool shouldRepaint(_OrnamentDividerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.scale != scale;
  }
}

// =============================================================================
// Stats grid — RPG-style ability scores
// =============================================================================

class _StatsGrid extends StatelessWidget {
  final NodeDexEntry entry;
  final SigilData sigil;
  final CardRarity rarity;
  final double scale;

  const _StatsGrid({
    required this.entry,
    required this.sigil,
    required this.rarity,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final stats = <_StatData>[
      _StatData(label: 'ENC', value: _formatCompact(entry.encounterCount)),
      _StatData(label: 'RNG', value: _formatDistance(entry.maxDistanceSeen)),
      _StatData(label: 'MSG', value: _formatCompact(entry.messageCount)),
      _StatData(
        label: 'SNR',
        value: entry.bestSnr != null ? '${entry.bestSnr}' : '--',
      ),
      _StatData(label: 'LNK', value: _formatCompact(entry.coSeenCount)),
      _StatData(label: 'AGE', value: _formatAge(entry.age)),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 2 * scale,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Top row: ENC, RNG, MSG
          Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) SizedBox(width: 4 * scale),
                Expanded(
                  child: _StatCell(
                    stat: stats[i],
                    color: _colorForIndex(i),
                    scale: scale,
                    isHighlight: _isHighlight(i),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 4 * scale),
          // Bottom row: SNR, LNK, AGE
          Row(
            children: [
              for (int i = 3; i < 6; i++) ...[
                if (i > 3) SizedBox(width: 4 * scale),
                Expanded(
                  child: _StatCell(
                    stat: stats[i],
                    color: _colorForIndex(i),
                    scale: scale,
                    isHighlight: _isHighlight(i),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _colorForIndex(int index) {
    return switch (index % 3) {
      0 => sigil.primaryColor,
      1 => sigil.secondaryColor,
      _ => sigil.tertiaryColor,
    };
  }

  /// Highlight cells with significant values to draw attention.
  bool _isHighlight(int index) {
    return switch (index) {
      0 => entry.encounterCount >= 20,
      1 => entry.maxDistanceSeen != null && entry.maxDistanceSeen! >= 1000,
      2 => entry.messageCount >= 10,
      3 => entry.bestSnr != null && entry.bestSnr! >= 10,
      4 => entry.coSeenCount >= 20,
      5 => entry.age.inDays >= 30,
      _ => false,
    };
  }

  static String _formatCompact(int value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '$value';
  }

  static String _formatDistance(double? meters) {
    if (meters == null) return '--';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
    return '${meters.round()}m';
  }

  static String _formatAge(Duration age) {
    if (age.inDays >= 365) {
      final years = age.inDays ~/ 365;
      return '${years}y';
    }
    if (age.inDays > 0) return '${age.inDays}d';
    if (age.inHours > 0) return '${age.inHours}h';
    return '${age.inMinutes}m';
  }
}

class _StatData {
  final String label;
  final String value;

  const _StatData({required this.label, required this.value});
}

class _StatCell extends StatelessWidget {
  final _StatData stat;
  final Color color;
  final double scale;
  final bool isHighlight;

  const _StatCell({
    required this.stat,
    required this.color,
    required this.scale,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgAlpha = isHighlight ? 0.12 : 0.06;
    final borderAlpha = isHighlight ? 0.25 : 0.12;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 7 * scale),
      decoration: BoxDecoration(
        color: color.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(6 * scale),
        border: Border.all(
          color: color.withValues(alpha: borderAlpha),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Value
          Text(
            stat.value,
            style: TextStyle(
              fontSize: 15 * scale,
              fontWeight: FontWeight.w700,
              color: isHighlight
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.85),
              fontFamily: AppTheme.fontFamily,
              height: 1.1,
            ),
          ),
          SizedBox(height: 1 * scale),
          // Label
          Text(
            stat.label,
            style: TextStyle(
              fontSize: 7.5 * scale,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: isHighlight ? 0.9 : 0.6),
              letterSpacing: 1.2 * scale,
              fontFamily: AppTheme.fontFamily,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Device info + palette line
// =============================================================================

class _DeviceAndPaletteLine extends StatelessWidget {
  final SigilData sigil;
  final String? hardwareModel;
  final String? firmwareVersion;
  final double scale;

  const _DeviceAndPaletteLine({
    required this.sigil,
    this.hardwareModel,
    this.firmwareVersion,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (hardwareModel != null && hardwareModel!.isNotEmpty) {
      parts.add(hardwareModel!);
    }
    if (firmwareVersion != null && firmwareVersion!.isNotEmpty) {
      parts.add('FW $firmwareVersion');
    }
    final deviceText = parts.isNotEmpty ? parts.join(' \u00B7 ') : null;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 3 * scale,
      ),
      child: Row(
        children: [
          // Color palette dots
          _PaletteDot(color: sigil.primaryColor, size: 7 * scale),
          SizedBox(width: 3 * scale),
          _PaletteDot(color: sigil.secondaryColor, size: 7 * scale),
          SizedBox(width: 3 * scale),
          _PaletteDot(color: sigil.tertiaryColor, size: 7 * scale),

          if (deviceText != null) ...[
            SizedBox(width: 8 * scale),
            Expanded(
              child: Text(
                deviceText,
                style: TextStyle(
                  fontSize: 7.5 * scale,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.3),
                  fontFamily: AppTheme.fontFamily,
                  letterSpacing: 0.3 * scale,
                ),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }
}

class _PaletteDot extends StatelessWidget {
  final Color color;
  final double size;

  const _PaletteDot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: size * 0.6,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Brand footer
// =============================================================================

class _BrandFooter extends StatelessWidget {
  final NodeDexEntry entry;
  final CardRarity rarity;
  final double scale;

  const _BrandFooter({
    required this.entry,
    required this.rarity,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy').format(entry.firstSeen);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: rarity.borderColor.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            rarity.borderColor.withValues(alpha: 0.04),
            const Color(0xFF0D1117).withValues(alpha: 0.3),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand mark
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hexagon_outlined,
                size: 9 * scale,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              SizedBox(width: 3 * scale),
              Text(
                'SOCIALMESH',
                style: TextStyle(
                  fontSize: 6.5 * scale,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.25),
                  letterSpacing: 1.5 * scale,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),

          // Rarity label
          Text(
            rarity.label,
            style: TextStyle(
              fontSize: 7 * scale,
              fontWeight: FontWeight.w800,
              color: rarity.borderColor.withValues(alpha: 0.7),
              letterSpacing: 1.0 * scale,
              fontFamily: AppTheme.fontFamily,
            ),
          ),

          // Discovery date
          Text(
            dateStr,
            style: TextStyle(
              fontSize: 6.5 * scale,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.25),
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
