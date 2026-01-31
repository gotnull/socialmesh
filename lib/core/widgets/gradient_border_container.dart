// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// A container with a gradient border where the top and left edges
/// have an accent color that blends into the default border on the
/// right and bottom edges.
class GradientBorderContainer extends StatelessWidget {
  const GradientBorderContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.borderWidth = 2.0,
    this.accentOpacity = 0.6,
    this.backgroundColor,
    this.accentColor,
    this.defaultBorderColor,
    this.padding,
  });

  /// The child widget to display inside the container.
  final Widget child;

  /// Border radius for the container.
  final double borderRadius;

  /// Width of the border.
  final double borderWidth;

  /// Opacity of the accent color (0.0 to 1.0).
  final double accentOpacity;

  /// Background color of the container. Defaults to card color from theme.
  final Color? backgroundColor;

  /// Accent color for top and left borders. Defaults to theme accent.
  final Color? accentColor;

  /// Default border color for right and bottom. Defaults to theme border.
  final Color? defaultBorderColor;

  /// Optional padding inside the container.
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? context.accentColor;
    final defaultBorder =
        defaultBorderColor ?? context.border.withValues(alpha: 0.5);
    final bgColor = backgroundColor ?? context.card;

    return CustomPaint(
      painter: _GradientBorderPainter(
        borderRadius: borderRadius,
        borderWidth: borderWidth,
        accentColor: accent.withValues(alpha: accentOpacity),
        defaultBorderColor: defaultBorder,
      ),
      child: Container(
        margin: EdgeInsets.all(borderWidth / 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius - borderWidth / 2),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Custom painter that draws a border with accent on top-left fading to default on bottom-right.
class _GradientBorderPainter extends CustomPainter {
  _GradientBorderPainter({
    required this.borderRadius,
    required this.borderWidth,
    required this.accentColor,
    required this.defaultBorderColor,
  });

  final double borderRadius;
  final double borderWidth;
  final Color accentColor;
  final Color defaultBorderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      borderWidth / 2,
      borderWidth / 2,
      size.width - borderWidth,
      size.height - borderWidth,
    );

    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius - borderWidth / 2),
    );

    // Sweep gradient going clockwise:
    // - Top-left corner: accent
    // - Top-right corner: blending
    // - Bottom-right: default
    // - Bottom-left: blending back to accent
    final gradient = SweepGradient(
      center: Alignment.center,
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: [
        accentColor, // 0° - right (we'll rotate)
        accentColor, // top-right corner
        defaultBorderColor, // right side
        defaultBorderColor, // bottom-right corner
        defaultBorderColor, // bottom
        defaultBorderColor, // bottom-left corner
        accentColor, // left side
        accentColor, // top-left corner / back to start
      ],
      stops: const [
        0.0, // top (after rotation)
        0.125, // top-right corner
        0.25, // right
        0.375, // bottom-right corner
        0.5, // bottom
        0.625, // bottom-left corner
        0.75, // left
        1.0, // back to top
      ],
      // Rotate -90° so 0 starts at top instead of right
      transform: const GradientRotation(-math.pi / 2),
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GradientBorderPainter oldDelegate) =>
      borderRadius != oldDelegate.borderRadius ||
      borderWidth != oldDelegate.borderWidth ||
      accentColor != oldDelegate.accentColor ||
      defaultBorderColor != oldDelegate.defaultBorderColor;
}
