// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:math';

import 'package:flutter/material.dart';

/// A [CustomPainter] that renders a live microphone-level waveform visualisation
/// from a rolling buffer of normalised amplitude samples.
///
/// The buffer is treated as a left-to-right time series: index 0 is the oldest
/// sample, the last index is the most recent. Each sample is displayed as a
/// centred vertical bar that mirrors above and below the horizontal axis.
///
/// Older bars fade toward [_minAlpha] and newer bars approach full opacity,
/// creating a natural history-trail effect. A minimum bar height is enforced
/// so the visualisation stays visible during silence.
class LiveWaveformPainter extends CustomPainter {
  const LiveWaveformPainter({required this.amplitudes, required this.color});

  /// Rolling amplitude buffer. Every value must be in [0.0, 1.0].
  final List<double> amplitudes;

  /// Base bar colour. Alpha is modulated per bar based on age.
  final Color color;

  // ── visual constants ──────────────────────────────────────────────────────

  static const double _minBarHeight = 3.0;
  static const double _gapFraction = 0.35; // fraction of slot consumed by gap
  static const double _minAlpha = 0.18;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final count = amplitudes.length;
    // Each bar occupies (slotWidth) total; gap is _gapFraction of that.
    final slotWidth = size.width / count;
    final barWidth = max(1.0, slotWidth * (1 - _gapFraction));
    final maxHalfHeight = (size.height / 2) - 2;
    final centerY = size.height / 2;

    final paint = Paint()..style = PaintingStyle.fill;
    final radius = Radius.circular(barWidth / 2);

    for (var i = 0; i < count; i++) {
      final amp = amplitudes[i].clamp(0.0, 1.0);
      final half = max(_minBarHeight, amp * maxHalfHeight);

      // Newer = brighter; oldest bar at _minAlpha, newest at 1.0.
      final ageFactor = i / (count - 1); // 0 = oldest, 1 = newest
      final alpha = _minAlpha + ageFactor * (1.0 - _minAlpha);
      paint.color = color.withValues(alpha: alpha);

      final x = i * slotWidth + (slotWidth - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barWidth / 2, centerY),
          width: barWidth,
          height: half * 2,
        ),
        radius,
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(LiveWaveformPainter old) =>
      !identical(amplitudes, old.amplitudes) || color != old.color;
}
