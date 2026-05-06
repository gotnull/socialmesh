// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../theme.dart';

/// Camera-feed overlay used by every QR scanner screen.
///
/// Dims the area outside a centered rounded-square cutout and draws four
/// rounded-corner brackets that hug the cutout. The caller passes the
/// active accent color (e.g. swap to success green while processing).
class QrScannerOverlay extends StatelessWidget {
  final Color cornerColor;
  final double cutoutSize;
  final double cutoutRadius;
  final double cornerSize;
  final double cornerThickness;
  final double cornerRadius;
  final double dimOpacity;

  const QrScannerOverlay({
    super.key,
    required this.cornerColor,
    this.cutoutSize = 280,
    this.cutoutRadius = AppTheme.radius16,
    this.cornerSize = 30,
    this.cornerThickness = 4,
    this.cornerRadius = 12,
    this.dimOpacity = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _QrDimOverlayPainter(
                color: Colors.black.withValues(alpha: dimOpacity),
                cutoutSize: cutoutSize,
                cutoutRadius: cutoutRadius,
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: cutoutSize,
              height: cutoutSize,
              child: Stack(
                children: [
                  _buildCorner(Alignment.topLeft),
                  _buildCorner(Alignment.topRight),
                  _buildCorner(Alignment.bottomLeft),
                  _buildCorner(Alignment.bottomRight),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    final isTop =
        alignment == Alignment.topLeft || alignment == Alignment.topRight;
    final isLeft =
        alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;

    return Positioned(
      top: isTop ? 0 : null,
      bottom: !isTop ? 0 : null,
      left: isLeft ? 0 : null,
      right: !isLeft ? 0 : null,
      child: SizedBox(
        width: cornerSize,
        height: cornerSize,
        child: CustomPaint(
          painter: _QrCornerPainter(
            color: cornerColor,
            thickness: cornerThickness,
            radius: cornerRadius,
            isTop: isTop,
            isLeft: isLeft,
          ),
        ),
      ),
    );
  }
}

class _QrCornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final double radius;
  final bool isTop;
  final bool isLeft;

  _QrCornerPainter({
    required this.color,
    required this.thickness,
    required this.radius,
    required this.isTop,
    required this.isLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, radius);
      path.arcToPoint(Offset(radius, 0), radius: Radius.circular(radius));
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width - radius, 0);
      path.arcToPoint(
        Offset(size.width, radius),
        radius: Radius.circular(radius),
      );
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height - radius);
      path.arcToPoint(
        Offset(radius, size.height),
        radius: Radius.circular(radius),
        clockwise: false,
      );
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width - radius, size.height);
      path.arcToPoint(
        Offset(size.width, size.height - radius),
        radius: Radius.circular(radius),
        clockwise: false,
      );
      path.lineTo(size.width, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _QrCornerPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.thickness != thickness ||
      oldDelegate.radius != radius ||
      oldDelegate.isTop != isTop ||
      oldDelegate.isLeft != isLeft;
}

class _QrDimOverlayPainter extends CustomPainter {
  final Color color;
  final double cutoutSize;
  final double cutoutRadius;

  _QrDimOverlayPainter({
    required this.color,
    required this.cutoutSize,
    required this.cutoutRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cutoutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cutoutSize,
      height: cutoutSize,
    );
    final outer = Path()..addRect(Offset.zero & size);
    final inner = Path()
      ..addRRect(
        RRect.fromRectAndRadius(cutoutRect, Radius.circular(cutoutRadius)),
      );
    final dim = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(dim, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _QrDimOverlayPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.cutoutSize != cutoutSize ||
      oldDelegate.cutoutRadius != cutoutRadius;
}
