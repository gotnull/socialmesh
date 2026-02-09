// SPDX-License-Identifier: GPL-3.0-or-later

// Holographic Effect — animated rainbow gradient overlay for rare+ cards.
//
// Renders a diagonal rainbow shimmer that drifts slowly across the card
// surface, creating the look of a premium holographic trading card.
// The effect is purely cosmetic and renders as a transparent overlay
// on top of the card content.
//
// Visual design:
//   - Diagonal gradient bands of spectral colors
//   - Slow continuous drift animation (no user interaction required)
//   - Opacity scales with rarity tier (rare < epic < legendary)
//   - Respects reduce-motion: falls back to a static subtle sheen
//   - Clipped to card bounds via parent ClipRRect
//
// Performance:
//   - Single CustomPainter per card, no widget-per-band
//   - Animation driven by a single AnimationController
//   - RepaintBoundary recommended on parent for isolation
//   - No allocations per frame — gradient is rebuilt only when
//     animation value changes

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'album_constants.dart';

/// Animated holographic shimmer overlay for collectible cards.
///
/// Place this as a child inside a Stack on top of the card content,
/// wrapped in a ClipRRect matching the card's border radius.
///
/// The [rarity] index controls shimmer intensity:
///   - 0–1 (common/uncommon): no effect rendered
///   - 2 (rare): subtle shimmer
///   - 3 (epic): moderate shimmer
///   - 4 (legendary): vivid shimmer
///
/// When [animate] is false (e.g. reduce-motion), a static gradient
/// is shown instead of the animated version.
///
/// Usage:
/// ```dart
/// ClipRRect(
///   borderRadius: BorderRadius.circular(10),
///   child: Stack(
///     children: [
///       CardContent(...),
///       HolographicEffect(rarityIndex: 4, animate: true),
///     ],
///   ),
/// )
/// ```
class HolographicEffect extends StatefulWidget {
  /// Rarity index: 0=common, 1=uncommon, 2=rare, 3=epic, 4=legendary.
  final int rarityIndex;

  /// Whether to animate the shimmer. Set false for reduce-motion
  /// or static image capture.
  final bool animate;

  /// Optional override for the shimmer cycle duration.
  final Duration? cycleDuration;

  const HolographicEffect({
    super.key,
    required this.rarityIndex,
    this.animate = true,
    this.cycleDuration,
  });

  @override
  State<HolographicEffect> createState() => _HolographicEffectState();
}

class _HolographicEffectState extends State<HolographicEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final duration = widget.cycleDuration ?? AlbumConstants.holoCycleDuration;
    _controller = AnimationController(vsync: this, duration: duration);

    if (widget.animate && _shouldRender) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(HolographicEffect oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.animate != oldWidget.animate ||
        widget.rarityIndex != oldWidget.rarityIndex) {
      if (widget.animate && _shouldRender) {
        if (!_controller.isAnimating) _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _shouldRender =>
      AlbumConstants.holoOpacityFor(widget.rarityIndex) > 0.0;

  @override
  Widget build(BuildContext context) {
    if (!_shouldRender) return const SizedBox.shrink();

    final opacity = AlbumConstants.holoOpacityFor(widget.rarityIndex);

    if (!widget.animate) {
      // Static sheen for reduce-motion.
      return Positioned.fill(
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: CustomPaint(
              painter: _HolographicPainter(
                phase: 0.3, // Fixed position for static sheen.
                opacity: 1.0,
              ),
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Opacity(
              opacity: opacity,
              child: CustomPaint(
                painter: _HolographicPainter(
                  phase: _controller.value,
                  opacity: 1.0,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Paints the holographic rainbow gradient bands.
///
/// The gradient is rotated at [AlbumConstants.holoAngle] radians and
/// shifted by [phase] (0.0–1.0) to create the drifting effect.
/// Each band is [AlbumConstants.holoBandWidth] wide in normalized
/// gradient space.
class _HolographicPainter extends CustomPainter {
  /// Current phase of the shimmer cycle (0.0–1.0).
  final double phase;

  /// Master opacity multiplier (typically 1.0; rarity opacity is
  /// applied at the widget level).
  final double opacity;

  _HolographicPainter({required this.phase, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;

    // Compute rotated gradient endpoints.
    // The gradient sweeps diagonally across the card.
    final angle = AlbumConstants.holoAngle;
    final diagonal = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    final cx = size.width / 2;
    final cy = size.height / 2;
    final dx = math.cos(angle) * diagonal;
    final dy = math.sin(angle) * diagonal;

    final start = Offset(cx - dx, cy - dy);
    final end = Offset(cx + dx, cy + dy);

    // Build color stops shifted by phase.
    // We create a repeating pattern of rainbow bands that slide
    // across the gradient space as phase advances.
    final colors = <Color>[];
    final stops = <double>[];
    final bandCount = AlbumConstants.holoColors.length;

    for (int i = 0; i < bandCount; i++) {
      final baseStop = i / (bandCount - 1);
      // Shift by phase, wrapping around.
      var shifted = (baseStop + phase) % 1.0;
      // Ensure stops are monotonically increasing by sorting later.
      colors.add(AlbumConstants.holoColors[i].withValues(alpha: opacity));
      stops.add(shifted);
    }

    // Sort stops (and corresponding colors) to ensure monotonic order
    // required by LinearGradient.
    final indexed = List<int>.generate(bandCount, (i) => i);
    indexed.sort((a, b) => stops[a].compareTo(stops[b]));

    final sortedColors = indexed.map((i) => colors[i]).toList();
    final sortedStops = indexed.map((i) => stops[i]).toList();

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: sortedColors,
      stops: sortedStops,
    );

    final shader = gradient.createShader(Rect.fromPoints(start, end));

    final paint = Paint()
      ..shader = shader
      ..blendMode = BlendMode.screen;

    canvas.drawRect(rect, paint);

    // Add a second pass with slight offset for depth.
    final secondPhase = (phase + 0.33) % 1.0;
    final secondColors = <Color>[];
    final secondStops = <double>[];

    for (int i = 0; i < bandCount; i++) {
      final baseStop = i / (bandCount - 1);
      var shifted = (baseStop + secondPhase) % 1.0;
      secondColors.add(
        AlbumConstants.holoColors[i].withValues(alpha: opacity * 0.4),
      );
      secondStops.add(shifted);
    }

    final secondIndexed = List<int>.generate(bandCount, (i) => i);
    secondIndexed.sort((a, b) => secondStops[a].compareTo(secondStops[b]));

    final secondSortedColors = secondIndexed
        .map((i) => secondColors[i])
        .toList();
    final secondSortedStops = secondIndexed.map((i) => secondStops[i]).toList();

    final secondGradient = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: secondSortedColors,
      stops: secondSortedStops,
    );

    // Slightly different angle for the second layer.
    final angle2 = angle + 0.8;
    final dx2 = math.cos(angle2) * diagonal;
    final dy2 = math.sin(angle2) * diagonal;
    final start2 = Offset(cx - dx2, cy - dy2);
    final end2 = Offset(cx + dx2, cy + dy2);

    final shader2 = secondGradient.createShader(Rect.fromPoints(start2, end2));

    final paint2 = Paint()
      ..shader = shader2
      ..blendMode = BlendMode.screen;

    canvas.drawRect(rect, paint2);
  }

  @override
  bool shouldRepaint(_HolographicPainter oldDelegate) {
    return phase != oldDelegate.phase || opacity != oldDelegate.opacity;
  }
}

/// A simpler holographic shimmer for use on mini card slots in the grid.
///
/// Uses a single-pass gradient with lower fidelity for performance
/// when many cards are visible simultaneously.
class MiniHolographicEffect extends StatefulWidget {
  /// Rarity index: 0=common, 1=uncommon, 2=rare, 3=epic, 4=legendary.
  final int rarityIndex;

  /// Whether to animate.
  final bool animate;

  const MiniHolographicEffect({
    super.key,
    required this.rarityIndex,
    this.animate = true,
  });

  @override
  State<MiniHolographicEffect> createState() => _MiniHolographicEffectState();
}

class _MiniHolographicEffectState extends State<MiniHolographicEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Slower cycle for mini cards to reduce visual noise in the grid.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    if (widget.animate && _shouldRender) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(MiniHolographicEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate ||
        widget.rarityIndex != oldWidget.rarityIndex) {
      if (widget.animate && _shouldRender) {
        if (!_controller.isAnimating) _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _shouldRender =>
      AlbumConstants.holoOpacityFor(widget.rarityIndex) > 0.0;

  @override
  Widget build(BuildContext context) {
    if (!_shouldRender) return const SizedBox.shrink();

    final opacity = AlbumConstants.holoOpacityFor(widget.rarityIndex) * 0.7;

    if (!widget.animate) {
      return Positioned.fill(
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: CustomPaint(painter: _MiniHoloPainter(phase: 0.3)),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Opacity(
              opacity: opacity,
              child: CustomPaint(
                painter: _MiniHoloPainter(phase: _controller.value),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Simplified single-pass holographic painter for mini cards.
class _MiniHoloPainter extends CustomPainter {
  final double phase;

  _MiniHoloPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;

    // Simple three-color sweep.
    final colors = [
      AlbumConstants.holoColors[0],
      AlbumConstants.holoColors[2],
      AlbumConstants.holoColors[4],
      AlbumConstants.holoColors[0],
    ];

    // Shift stops by phase.
    final stops = <double>[
      (0.0 + phase) % 1.0,
      (0.33 + phase) % 1.0,
      (0.66 + phase) % 1.0,
      (1.0 + phase) % 1.0,
    ];

    // Sort for monotonic order.
    final indexed = [0, 1, 2, 3];
    indexed.sort((a, b) => stops[a].compareTo(stops[b]));

    final sortedColors = indexed.map((i) => colors[i]).toList();
    final sortedStops = indexed.map((i) => stops[i]).toList();

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: sortedColors,
      stops: sortedStops,
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..blendMode = BlendMode.screen;

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_MiniHoloPainter oldDelegate) {
    return phase != oldDelegate.phase;
  }
}
