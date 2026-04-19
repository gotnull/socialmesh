// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// [CustomPainter] that renders a compact waveform visualiser from pre-computed
/// amplitude buckets.
///
/// The waveform is drawn centred on the horizontal midline of [size].
/// Bars to the left of [progress] are filled with [playedColor]; bars to the
/// right are drawn with [unplayedColor].  A hairline playhead marker is drawn
/// at exactly [progress] × width.
///
/// All colours support transparency:  use `.withValues(alpha: …)` on the
/// colours you supply to achieve the desired density.
class WaveformPainter extends CustomPainter {
  const WaveformPainter({
    required this.peaks,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    required this.borderRadius,
    this.playheadColor,
    this.minBarHeight = 3,
  });

  /// Normalised peak amplitudes, one value per bucket. Values must be in
  /// [0.0, 1.0]. Produced by [WaveformAnalyser._computePeaks].
  final Float32List peaks;

  /// Playback progress in [0.0, 1.0]. Bars at or before this position are
  /// drawn with [playedColor].
  final double progress;

  /// Bar colour for the played portion.
  final Color playedColor;

  /// Bar colour for the unplayed portion.
  final Color unplayedColor;

  /// Optional override for the playhead line; defaults to [playedColor].
  final Color? playheadColor;

  /// Corner radius applied to each amplitude bar.
  final double borderRadius;

  /// Minimum rendered bar height in logical pixels, preventing bars from being
  /// invisible at zero amplitude.
  final double minBarHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;

    final int n = peaks.length;
    // Gap between bars is 30% of bar width.
    final double barWidth = (size.width / n) * 0.7;
    final double gap = (size.width / n) * 0.3;
    final double halfH = size.height / 2;

    final playedPaint = Paint()
      ..color = playedColor
      ..style = PaintingStyle.fill;

    final unplayedPaint = Paint()
      ..color = unplayedColor
      ..style = PaintingStyle.fill;

    final double playedX = progress.clamp(0.0, 1.0) * size.width;

    for (var i = 0; i < n; i++) {
      final double left = i * (barWidth + gap);
      final double centre = left + barWidth / 2;

      final double amplitude = peaks[i].clamp(0.0, 1.0);
      final double rawHeight = amplitude * size.height;
      final double barHeight = math.max(rawHeight, minBarHeight);
      final double top = halfH - barHeight / 2;

      final Rect rect = Rect.fromLTWH(left, top, barWidth, barHeight);
      final RRect rRect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(borderRadius),
      );

      canvas.drawRRect(rRect, centre <= playedX ? playedPaint : unplayedPaint);
    }

    // Playhead — thin vertical line.
    if (progress > 0 && progress < 1) {
      final headPaint = Paint()
        ..color = playheadColor ?? playedColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(playedX, 0),
        Offset(playedX, size.height),
        headPaint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.peaks != peaks ||
        oldDelegate.progress != progress ||
        oldDelegate.playedColor != playedColor ||
        oldDelegate.unplayedColor != unplayedColor;
  }
}

/// A shimmering placeholder drawn while waveform analysis is pending.
///
/// Uses a subtle animated shimmer sweep from left to right.
/// The width / height semantics are identical to [WaveformPainter].
class WaveformSkeletonPainter extends CustomPainter {
  const WaveformSkeletonPainter({
    required this.shimmerProgress,
    required this.baseColor,
    required this.highlightColor,
    required this.borderRadius,
    this.bucketCount = 60,
    this.seed = 42,
  });

  /// Shimmer sweep position [0.0, 1.0] driven by an animation controller.
  final double shimmerProgress;
  final Color baseColor;
  final Color highlightColor;
  final double borderRadius;
  final int bucketCount;

  /// Seed for the deterministic fake waveform — keeps the shimmer stable.
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final int n = bucketCount;
    final double barWidth = (size.width / n) * 0.7;
    final double gap = (size.width / n) * 0.3;
    final double halfH = size.height / 2;
    final double sweepX = shimmerProgress * (size.width + 60) - 30;

    for (var i = 0; i < n; i++) {
      final double left = i * (barWidth + gap);
      final double centre = left + barWidth / 2;
      final double t = ((centre - sweepX) / 60).clamp(-1.0, 1.0);
      // Cosine blend: peak at centre of sweep, fade to base at edges.
      final double blend = (1 - t.abs()).clamp(0.0, 1.0);
      final Color barColor = Color.lerp(baseColor, highlightColor, blend)!;

      final double amplitude = 0.15 + rng.nextDouble() * 0.6;
      final double barHeight = math.max(amplitude * size.height, 3.0);
      final Rect rect = Rect.fromLTWH(
        left,
        halfH - barHeight / 2,
        barWidth,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(borderRadius)),
        Paint()..color = barColor,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformSkeletonPainter oldDelegate) =>
      oldDelegate.shimmerProgress != shimmerProgress;
}
