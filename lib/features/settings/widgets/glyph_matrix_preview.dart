import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/glyph_service.dart';

/// Visual preview of the glyph matrix showing zone allocation
/// Based on Nothing Phone 3 specs: 440x440px matrix, 13.05x13.05px LEDs, 25x25 grid
class GlyphMatrixPreview extends StatelessWidget {
  final List<GlyphZone> activeZones;
  final bool showLabels;

  const GlyphMatrixPreview({
    super.key,
    this.activeZones = const [],
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          if (showLabels) ...[
            Text(
              'Glyph Matrix Layout',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '25x25 LED Grid (440x440px)',
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
          ],
          AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: _GlyphMatrixPainter(
                activeZones: activeZones,
                primaryColor: context.primary,
                backgroundColor: context.background,
                borderColor: context.border.withValues(alpha: 0.3),
              ),
            ),
          ),
          if (showLabels) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: GlyphZone.values.map((zone) {
                final isActive = activeZones.contains(zone);
                return _ZoneLegendItem(
                  zone: zone,
                  isActive: isActive,
                  color: isActive ? context.primary : context.textSecondary,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ZoneLegendItem extends StatelessWidget {
  final GlyphZone zone;
  final bool isActive;
  final Color color;

  const _ZoneLegendItem({
    required this.zone,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? color : Colors.transparent,
            border: Border.all(color: color, width: isActive ? 2 : 1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          zone.displayName,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _GlyphMatrixPainter extends CustomPainter {
  final List<GlyphZone> activeZones;
  final Color primaryColor;
  final Color backgroundColor;
  final Color borderColor;

  _GlyphMatrixPainter({
    required this.activeZones,
    required this.primaryColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridSize = 25; // 25×25 LED grid
    final cellSize = size.width / gridSize;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw circular background
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Draw circular border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, borderPaint);

    // Draw LED grid within circular boundary
    // Nothing Phone 3 has LEDs arranged in a circular pattern
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final x = col * cellSize + cellSize / 2;
        final y = row * cellSize + cellSize / 2;
        final pos = Offset(x, y);

        // Check if LED is within circular boundary
        final distanceFromCenter = (pos - center).distance;
        if (distanceFromCenter > radius - cellSize) continue;

        // Determine which zone this LED belongs to
        final zone = _getZoneForPosition(row, col, gridSize);
        final isActive = zone != null && activeZones.contains(zone);

        // Draw LED
        final ledPaint = Paint()
          ..color = isActive
              ? primaryColor.withValues(alpha: 0.8)
              : borderColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: pos,
              width: cellSize * 0.7,
              height: cellSize * 0.7,
            ),
            Radius.circular(cellSize * 0.15),
          ),
          ledPaint,
        );
      }
    }
  }

  /// Map LED position to glyph zone
  /// Based on typical Nothing Phone layout - this is approximate
  GlyphZone? _getZoneForPosition(int row, int col, int gridSize) {
    final centerRow = gridSize / 2;
    final centerCol = gridSize / 2;

    // Zone A: Camera (top area)
    if (row < gridSize * 0.25 && (col - centerCol).abs() < gridSize * 0.2) {
      return GlyphZone.a;
    }

    // Zone B: Diagonal strip (upper right to lower left)
    if ((row - col).abs() < gridSize * 0.15 &&
        row > gridSize * 0.2 &&
        row < gridSize * 0.8) {
      return GlyphZone.b;
    }

    // Zone C: USB-C port (bottom center)
    if (row > gridSize * 0.8 && (col - centerCol).abs() < gridSize * 0.15) {
      return GlyphZone.c;
    }

    // Zone D: Lower strip (bottom area)
    if (row > gridSize * 0.7 &&
        row < gridSize * 0.85 &&
        (col - centerCol).abs() < gridSize * 0.35) {
      return GlyphZone.d;
    }

    // Zone E: Battery (right side vertical)
    if (col > gridSize * 0.7 && (row - centerRow).abs() < gridSize * 0.3) {
      return GlyphZone.e;
    }

    return null;
  }

  @override
  bool shouldRepaint(_GlyphMatrixPainter oldDelegate) {
    return activeZones != oldDelegate.activeZones;
  }
}
