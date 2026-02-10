// Vendored from vs_node_view v2.1.1 — BSD-3-Clause
// Import paths rewritten for Socialmesh vendoring.
// Modified: Added glow/shadow pass underneath main lines for sci-fi aesthetic.

import 'package:flutter/material.dart';

import '../../data/vs_interface.dart';

class MultiGradientLinePainter extends CustomPainter {
  /// Draws lines between all connected interfaces with a gradient and glow
  /// effect.
  ///
  /// Each connection gets a glow pass (wider, blurred, semi-transparent)
  /// rendered beneath the main crisp line, producing the sci-fi neon-wire
  /// aesthetic that matches the Socialmesh constellation view.
  MultiGradientLinePainter({
    required this.data,
    this.glowEnabled = true,
    this.glowWidth = 8.0,
    this.glowOpacity = 0.3,
    this.lineWidth = 2.0,
  });

  final List<VSInputData> data;

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
    for (var input in data) {
      if (input.widgetOffset == null ||
          input.nodeData?.widgetOffset == null ||
          input.connectedInterface?.widgetOffset == null ||
          input.connectedInterface?.nodeData?.widgetOffset == null) {
        continue;
      }

      final startPoint = input.widgetOffset! + input.nodeData!.widgetOffset;
      final endPoint =
          input.connectedInterface!.widgetOffset! +
          input.connectedInterface!.nodeData!.widgetOffset;

      var colors = [
        input.connectedInterface?.interfaceColor ?? Colors.grey,
        input.interfaceColor,
      ];
      if (endPoint.dx <= 0) colors = colors.reversed.toList();

      // Avoid degenerate gradient rect (zero-width or zero-height)
      final rect = Rect.fromPoints(startPoint, endPoint);
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
          (input.connectedInterface?.interfaceColor ?? Colors.grey).withValues(
            alpha: glowOpacity,
          ),
          input.interfaceColor.withValues(alpha: glowOpacity),
        ];
        final orderedGlowColors = endPoint.dx <= 0
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

        canvas.drawLine(startPoint, endPoint, glowPaint);
      }

      // Main crisp line
      final paint = Paint()
        ..strokeWidth = lineWidth
        ..strokeCap = StrokeCap.round
        ..shader = gradient;

      canvas.drawLine(startPoint, endPoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MultiGradientLinePainter oldDelegate) {
    return true;
  }
}
