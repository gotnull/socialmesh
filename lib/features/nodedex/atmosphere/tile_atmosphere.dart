// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tile Atmosphere — per-tile micro particle effects for NodeDex list tiles.
//
// Each tile gets a small, contained atmosphere effect driven by the node's
// primary trait and patina score. Effects are:
//   - Relay nodes    → warm amber ember dots that gently pulse
//   - Courier nodes  → amber-green ember dots (data carriers)
//   - Ghost nodes    → faint grey mist wisps that drift
//   - Drifter nodes  → single faint mist wisp (intermittent presence)
//   - Beacon nodes   → twinkling star points
//   - Sentinel nodes → subtle blue rain streaks
//   - Anchor nodes   → steady steel-blue rain streaks (fixed infrastructure)
//   - Wanderer nodes → twinkling stars with faint warmth
//   - Unknown/other  → very faint starlight
//
// All particles are deterministic — seeded by nodeNum — so they produce
// consistent patterns regardless of scroll position or widget lifecycle.
// Animation is driven by a shared AnimationController from the parent
// screen, so there is only ONE ticker for the entire list.
//
// The painting is pure math: no allocation, no particle pools, no spawn
// logic. Each paint call computes 3-8 particle positions from the seed
// and elapsed time. This is extremely cheap at ~60fps.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/nodedex_entry.dart';

// =============================================================================
// Tile atmosphere overlay widget
// =============================================================================

/// A widget that renders a subtle per-tile atmosphere effect behind its child.
///
/// The effect is trait-specific and deterministic based on [nodeNum].
/// Animation is driven by [animation] which should be a shared controller
/// from the parent screen (one ticker for the entire list).
///
/// When [enabled] is false, returns [child] directly with zero cost.
///
/// Usage:
/// ```dart
/// TileAtmosphere(
///   nodeNum: entry.nodeNum,
///   trait: traitResult.primary,
///   patinaScore: patinaResult.score,
///   animation: _atmosphereController,
///   enabled: atmosphereEnabled,
///   child: myTileContent,
/// )
/// ```
class TileAtmosphere extends StatelessWidget {
  /// The node number — used as the deterministic seed for particle layout.
  final int nodeNum;

  /// The node's primary trait — determines which effect type to render.
  final NodeTrait trait;

  /// The node's patina score (0–100) — modulates effect intensity.
  final double patinaScore;

  /// Shared animation that drives the painting. Should be a repeating
  /// controller from the parent screen.
  final Animation<double> animation;

  /// Whether the atmosphere system is enabled. When false, returns
  /// [child] directly with no overhead.
  final bool enabled;

  /// The tile content to render on top of the atmosphere.
  final Widget child;

  const TileAtmosphere({
    super.key,
    required this.nodeNum,
    required this.trait,
    required this.patinaScore,
    required this.animation,
    required this.enabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => CustomPaint(
        foregroundPainter: _TileAtmospherePainter(
          nodeNum: nodeNum,
          trait: trait,
          patinaScore: patinaScore,
          elapsed: animation.value * _kCycleDuration,
          isDark: isDark,
        ),
        child: child,
      ),
      child: child,
    );
  }
}

// =============================================================================
// Constants
// =============================================================================

/// Full cycle duration in seconds. The animation controller repeats over
/// this period, and all particle motion is computed modulo this value.
const double _kCycleDuration = 20.0;

/// Base particle counts per trait. Scaled by patina score.
int _particleCount(NodeTrait trait, double patina) {
  final base = switch (trait) {
    NodeTrait.relay => 4,
    NodeTrait.courier => 4,
    NodeTrait.ghost => 2,
    NodeTrait.drifter => 2,
    NodeTrait.beacon => 5,
    NodeTrait.sentinel => 3,
    NodeTrait.anchor => 3,
    NodeTrait.wanderer => 3,
    NodeTrait.unknown => 1,
  };
  // Patina adds 0-2 extra particles.
  final bonus = (patina / 50.0).clamp(0.0, 1.0) * 2;
  return base + bonus.floor();
}

/// Maximum alpha for tile atmosphere effects. Much lower than the
/// full-screen atmosphere — these need to be barely perceptible.
const double _kMaxAlpha = 0.12;

// =============================================================================
// Trait-specific color palettes
// =============================================================================

/// Get the particle color palette for a given trait and theme.
List<Color> _palette(NodeTrait trait, bool isDark) {
  return switch (trait) {
    // Relay: warm amber-orange
    NodeTrait.relay =>
      isDark
          ? const [Color(0xFFE8913A), Color(0xFFD4782E), Color(0xFFF0A050)]
          : const [Color(0xFFC07030), Color(0xFFB06028), Color(0xFFD09040)],
    // Courier: amber-green (data flow warmth)
    NodeTrait.courier =>
      isDark
          ? const [Color(0xFFD4A03A), Color(0xFFC0B040), Color(0xFFE0C060)]
          : const [Color(0xFFA08028), Color(0xFF908020), Color(0xFFB09838)],
    // Ghost: pale grey-blue
    NodeTrait.ghost =>
      isDark
          ? const [Color(0xFFA0B0C0), Color(0xFF8090A0), Color(0xFFB0BCC8)]
          : const [Color(0xFF607080), Color(0xFF506070), Color(0xFF708090)],
    // Drifter: faint mist (intermittent, ephemeral)
    NodeTrait.drifter =>
      isDark
          ? const [Color(0xFFA0A8B0), Color(0xFF909098)]
          : const [Color(0xFF606868), Color(0xFF505858)],
    // Beacon: cool cyan-white
    NodeTrait.beacon =>
      isDark
          ? const [Color(0xFFD0D8E8), Color(0xFFC8D0E0), Color(0xFFB0C0D8)]
          : const [Color(0xFF606878), Color(0xFF505868), Color(0xFF707880)],
    // Sentinel: steel blue
    NodeTrait.sentinel =>
      isDark
          ? const [Color(0xFF6B8FA3), Color(0xFF7BA4B8), Color(0xFF809BB0)]
          : const [Color(0xFF4A6A7A), Color(0xFF5A7A8A), Color(0xFF506878)],
    // Anchor: deep steel-blue (persistent infrastructure)
    NodeTrait.anchor =>
      isDark
          ? const [Color(0xFF5A7A90), Color(0xFF6B8DA0), Color(0xFF708898)]
          : const [Color(0xFF3A5A6A), Color(0xFF4A6878), Color(0xFF405868)],
    // Wanderer: warm white with faint gold (mobile explorer)
    NodeTrait.wanderer =>
      isDark
          ? const [Color(0xFFD0D8E8), Color(0xFFE0D8C0), Color(0xFFF0E8D0)]
          : const [Color(0xFF606878), Color(0xFF707060), Color(0xFF808070)],
    // Unknown: very faint white
    NodeTrait.unknown =>
      isDark ? const [Color(0xFFB0B8C0)] : const [Color(0xFF707880)],
  };
}

// =============================================================================
// Painter
// =============================================================================

/// Deterministic per-tile atmosphere painter.
///
/// Renders 2-7 particles per tile based on the node's trait and patina.
/// All particle positions and animations are derived from the nodeNum
/// seed and elapsed time — no state, no allocation, fully deterministic.
class _TileAtmospherePainter extends CustomPainter {
  final int nodeNum;
  final NodeTrait trait;
  final double patinaScore;
  final double elapsed;
  final bool isDark;

  final Paint _paint = Paint()..isAntiAlias = true;

  _TileAtmospherePainter({
    required this.nodeNum,
    required this.trait,
    required this.patinaScore,
    required this.elapsed,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rng = math.Random(nodeNum);
    final count = _particleCount(trait, patinaScore);
    final colors = _palette(trait, isDark);

    // Patina intensity multiplier: low patina = subtle, high patina = richer.
    final intensity = 0.4 + (patinaScore / 100.0).clamp(0.0, 1.0) * 0.6;

    for (int i = 0; i < count; i++) {
      // Deterministic particle seed values.
      final baseX = rng.nextDouble();
      final baseY = rng.nextDouble();
      final phase = rng.nextDouble() * math.pi * 2;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final colorIndex = rng.nextInt(colors.length);
      final particleSize = 0.6 + rng.nextDouble() * 1.4;

      // Dispatch to trait-specific rendering.
      switch (trait) {
        case NodeTrait.relay:
        case NodeTrait.courier:
          _drawEmber(
            canvas,
            size,
            baseX,
            baseY,
            phase,
            speed,
            colors[colorIndex],
            particleSize,
            intensity,
          );
        case NodeTrait.ghost:
        case NodeTrait.drifter:
          _drawMist(
            canvas,
            size,
            baseX,
            baseY,
            phase,
            speed,
            colors[colorIndex],
            particleSize * 8,
            intensity,
          );
        case NodeTrait.sentinel:
        case NodeTrait.anchor:
          _drawRain(
            canvas,
            size,
            baseX,
            baseY,
            phase,
            speed,
            colors[colorIndex],
            particleSize,
            intensity,
          );
        case NodeTrait.beacon:
        case NodeTrait.wanderer:
        case NodeTrait.unknown:
          _drawStar(
            canvas,
            size,
            baseX,
            baseY,
            phase,
            speed,
            colors[colorIndex],
            particleSize,
            intensity,
          );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Ember — rising glowing dots with gentle horizontal wander
  // ---------------------------------------------------------------------------

  void _drawEmber(
    Canvas canvas,
    Size size,
    double baseX,
    double baseY,
    double phase,
    double speed,
    Color color,
    double radius,
    double intensity,
  ) {
    // Embers rise slowly, wrapping around vertically.
    final t = elapsed * speed * 0.08 + phase;
    final y = size.height * (1.0 - (t % 1.0));
    final x =
        size.width * baseX + math.sin(t * 2.0 + phase) * size.width * 0.06;

    // Pulse brightness.
    final pulse = 0.5 + 0.5 * math.sin(elapsed * speed * 1.5 + phase);
    final alpha = (_kMaxAlpha * intensity * pulse).clamp(0.0, _kMaxAlpha);

    if (alpha < 0.005) return;

    final center = Offset(x.clamp(0, size.width), y);

    // Glow halo.
    final glowRadius = radius * 4.0;
    final glowAlpha = (alpha * 0.5).clamp(0.0, 1.0);
    _paint
      ..shader = ui.Gradient.radial(
        center,
        glowRadius,
        [color.withValues(alpha: glowAlpha), color.withValues(alpha: 0)],
        [0.0, 1.0],
      )
      ..style = PaintingStyle.fill
      ..maskFilter = null;
    canvas.drawCircle(center, glowRadius, _paint);
    _paint.shader = null;

    // Core dot.
    _paint
      ..color = color.withValues(alpha: (alpha * 1.5).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, _paint);
  }

  // ---------------------------------------------------------------------------
  // Mist — large soft drifting blobs
  // ---------------------------------------------------------------------------

  void _drawMist(
    Canvas canvas,
    Size size,
    double baseX,
    double baseY,
    double phase,
    double speed,
    Color color,
    double radius,
    double intensity,
  ) {
    // Mist drifts slowly horizontally, oscillating vertically.
    final t = elapsed * speed * 0.03 + phase;
    final x = size.width * ((baseX + t * 0.5) % 1.2 - 0.1);
    final y =
        size.height * baseY + math.sin(t * 0.7 + phase) * size.height * 0.05;

    // Slow fade in/out cycle.
    final fade = 0.3 + 0.7 * ((math.sin(t * 0.4 + phase) + 1) / 2);
    final alpha = (_kMaxAlpha * intensity * fade * 0.5).clamp(0.0, _kMaxAlpha);

    if (alpha < 0.003) return;

    final center = Offset(x.clamp(-radius, size.width + radius), y);

    // Soft radial gradient blob.
    _paint
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.4),
          color.withValues(alpha: 0),
        ],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.3);
    canvas.drawCircle(center, radius, _paint);
    _paint
      ..shader = null
      ..maskFilter = null;
  }

  // ---------------------------------------------------------------------------
  // Rain — thin vertical streaks falling down
  // ---------------------------------------------------------------------------

  void _drawRain(
    Canvas canvas,
    Size size,
    double baseX,
    double baseY,
    double phase,
    double speed,
    Color color,
    double strokeWidth,
    double intensity,
  ) {
    // Rain falls downward, wrapping around vertically.
    final t = elapsed * speed * 0.15 + phase;
    final y = size.height * ((t + baseY) % 1.3 - 0.15);
    final x =
        size.width * baseX +
        math.sin(phase) * size.width * 0.02; // slight static drift

    final streakLength = 6.0 + speed * 8.0;
    final alpha = (_kMaxAlpha * intensity * 0.8).clamp(0.0, _kMaxAlpha);

    if (alpha < 0.005) return;
    if (y < -streakLength || y > size.height + streakLength) return;

    _paint
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = strokeWidth * 0.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(x, y),
      Offset(x + math.sin(phase) * 1.0, y + streakLength),
      _paint,
    );
  }

  // ---------------------------------------------------------------------------
  // Star — stationary twinkling points
  // ---------------------------------------------------------------------------

  void _drawStar(
    Canvas canvas,
    Size size,
    double baseX,
    double baseY,
    double phase,
    double speed,
    Color color,
    double radius,
    double intensity,
  ) {
    // Stars are stationary — they just twinkle in place.
    final x = size.width * baseX;
    final y = size.height * baseY;

    // Twinkle: sine wave modulates brightness.
    final twinkle =
        0.2 + 0.8 * ((math.sin(elapsed * speed * 0.8 + phase) + 1) / 2);
    final alpha = (_kMaxAlpha * intensity * twinkle).clamp(0.0, _kMaxAlpha);

    if (alpha < 0.005) return;

    final center = Offset(x, y);

    // Glow halo for larger stars.
    if (radius > 1.2) {
      final glowRadius = radius * 3.0;
      final glowAlpha = (alpha * 0.3).clamp(0.0, 1.0);
      _paint
        ..shader = ui.Gradient.radial(
          center,
          glowRadius,
          [color.withValues(alpha: glowAlpha), color.withValues(alpha: 0)],
          [0.0, 1.0],
        )
        ..style = PaintingStyle.fill
        ..maskFilter = null;
      canvas.drawCircle(center, glowRadius, _paint);
      _paint.shader = null;
    }

    // Core point.
    _paint
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, _paint);
  }

  @override
  bool shouldRepaint(_TileAtmospherePainter oldDelegate) {
    // Always repaint since elapsed changes every frame.
    // The AnimatedBuilder only rebuilds when the animation ticks,
    // so this is called at most once per frame.
    return true;
  }
}
