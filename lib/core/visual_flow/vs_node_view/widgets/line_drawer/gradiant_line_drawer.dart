// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.
// Modified: Added glow/shadow pass underneath main line for sci-fi aesthetic.

import 'package:flutter/material.dart';

class GradientLinePainter extends CustomPainter {
  /// Draws a line between 2 points with a gradient and a glow effect.
  ///
  /// The glow is rendered as a wider, semi-transparent shadow pass beneath
  /// the main crisp line, giving the sci-fi neon-wire aesthetic.
  GradientLinePainter({
    this.startPoint,
    this.startColor,
    this.endPoint,
    this.endColor,
    this.glowEnabled = true,
    this.glowWidth = 8.0,
    this.glowOpacity = 0.3,
    this.lineWidth = 2.0,
  });

  final Offset? startPoint;
  final Color? startColor;

  final Offset? endPoint;
  final Color? endColor;

  /// Whether the glow effect is rendered beneath the main line.
  final bool glowEnabled;

  /// The width of the glow pass. Should be wider than [lineWidth].
  final double glowWidth;

  /// The opacity of the glow pass.
  final double glowOpacity;

  /// The width of the main crisp line.
  final double lineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (startPoint == null || endPoint == null) return;

    var colors = [startColor ?? Colors.grey, endColor ?? Colors.grey];
    if (endPoint!.dx <= 0) colors = colors.reversed.toList();

    final rect = Rect.fromPoints(startPoint!, endPoint!);

    // Avoid degenerate gradient rect (zero-width or zero-height)
    final gradientRect = rect.width == 0 && rect.height == 0
        ? Rect.fromLTWH(rect.left, rect.top, 1, 1)
        : rect;

    final gradient = LinearGradient(
      colors: colors,
      stops: const [0.0, 1.0],
    ).createShader(gradientRect);

    // Glow pass — wider, blurred, semi-transparent
    if (glowEnabled) {
      final glowColors = [
        (startColor ?? Colors.grey).withValues(alpha: glowOpacity),
        (endColor ?? Colors.grey).withValues(alpha: glowOpacity),
      ];
      final orderedGlowColors = endPoint!.dx <= 0
          ? glowColors.reversed.toList()
          : glowColors;

      final glowGradient = LinearGradient(
        colors: orderedGlowColors,
        stops: const [0.0, 1.0],
      ).createShader(gradientRect);

      final glowPaint = Paint()
        ..strokeWidth = glowWidth
        ..strokeCap = StrokeCap.round
        ..shader = glowGradient
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

      canvas.drawLine(startPoint!, endPoint!, glowPaint);
    }

    // Main crisp line
    final paint = Paint()
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..shader = gradient;

    canvas.drawLine(startPoint!, endPoint!, paint);
  }

  @override
  bool shouldRepaint(covariant GradientLinePainter oldDelegate) {
    return startPoint != oldDelegate.startPoint ||
        endPoint != oldDelegate.endPoint ||
        startColor != oldDelegate.startColor ||
        endColor != oldDelegate.endColor ||
        glowEnabled != oldDelegate.glowEnabled ||
        glowWidth != oldDelegate.glowWidth ||
        glowOpacity != oldDelegate.glowOpacity ||
        lineWidth != oldDelegate.lineWidth;
  }
}
