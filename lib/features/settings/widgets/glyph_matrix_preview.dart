import 'package:flutter/material.dart';

import '../../../services/glyph_service.dart';

/// Simplified Glyph Matrix Preview for the pattern builder screen.
/// Shows a visual representation of the 5-zone glyph interface.
class GlyphMatrixPreview extends StatelessWidget {
  const GlyphMatrixPreview({
    super.key,
    this.activeZones = const [],
    this.showLabels = false,
    this.accentColor = const Color(0xFF00D4FF),
  });

  final List<GlyphZone> activeZones;
  final bool showLabels;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(
            painter: _ZonePainter(
              activeZones: activeZones,
              showLabels: showLabels,
              accentColor: accentColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _ZonePainter extends CustomPainter {
  final List<GlyphZone> activeZones;
  final bool showLabels;
  final Color accentColor;

  _ZonePainter({
    required this.activeZones,
    required this.showLabels,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Phone outline
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.15,
        size.height * 0.05,
        size.width * 0.7,
        size.height * 0.9,
      ),
      const Radius.circular(16),
    );
    paint.color = const Color(0xFF1A1A1A);
    canvas.drawRRect(phoneRect, paint);

    // Draw zones
    final zones = _getZoneRects(size);
    for (final entry in zones.entries) {
      final zone = entry.key;
      final rect = entry.value;
      final isActive = activeZones.contains(zone);

      // Zone background
      paint.color = isActive
          ? accentColor.withValues(alpha: 0.6)
          : const Color(0xFF2A2A2A);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint,
      );

      // Glow if active
      if (isActive) {
        final glowPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          glowPaint,
        );
      }

      // Label
      if (showLabels) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: zone.displayName,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(
            rect.center.dx - textPainter.width / 2,
            rect.center.dy - textPainter.height / 2,
          ),
        );
      }
    }
  }

  Map<GlyphZone, Rect> _getZoneRects(Size size) {
    final w = size.width;
    final h = size.height;
    final left = w * 0.18;
    final right = w * 0.82;
    final zoneW = right - left;

    return {
      // Zone A - Camera area (top)
      GlyphZone.a: Rect.fromLTWH(left, h * 0.08, zoneW, h * 0.15),

      // Zone B - Diagonal strip
      GlyphZone.b: Rect.fromLTWH(left, h * 0.26, zoneW, h * 0.12),

      // Zone C - USB-C area (middle)
      GlyphZone.c: Rect.fromLTWH(left, h * 0.42, zoneW, h * 0.15),

      // Zone D - Lower strip
      GlyphZone.d: Rect.fromLTWH(left, h * 0.60, zoneW, h * 0.12),

      // Zone E - Battery area (bottom)
      GlyphZone.e: Rect.fromLTWH(left, h * 0.76, zoneW, h * 0.15),
    };
  }

  @override
  bool shouldRepaint(_ZonePainter oldDelegate) =>
      activeZones != oldDelegate.activeZones ||
      showLabels != oldDelegate.showLabels;
}
