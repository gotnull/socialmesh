// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../providers/tak_navigation_provider.dart';
import '../utils/cot_affiliation.dart';

/// Bloodhound-style navigation screen showing bearing and distance
/// from the user's position to a target TAK entity.
class TakNavigateScreen extends ConsumerWidget {
  const TakNavigateScreen({
    super.key,
    required this.targetUid,
    required this.initialCallsign,
  });

  final String targetUid;
  final String initialCallsign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(takNavigationProvider(targetUid));
    final affiliation = parseAffiliation(nav.target.type);
    final affiliationColor = affiliation.color;
    final callsign = nav.target.callsign ?? initialCallsign;

    AppLogging.tak(
      'Navigation started: target=$callsign, '
      'bearing=${nav.formattedBearing ?? "N/A"}, '
      'distance=${nav.formattedDistance ?? "N/A"}',
    );

    return GlassScaffold.body(
      title: 'Navigate to $callsign',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Compass with bearing arrow.
            const SizedBox(height: 16),
            if (nav.hasUserPosition && nav.bearingDegrees != null)
              _BearingCompass(
                bearingDegrees: nav.bearingDegrees!,
                affiliationColor: affiliationColor,
              )
            else
              _NoPositionCard(),
            const SizedBox(height: 24),
            // Distance and speed info.
            if (nav.hasUserPosition && nav.distanceKm != null) ...[
              Text(
                nav.formattedDistance!,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                nav.formattedBearing ?? '',
                style: TextStyle(
                  fontSize: 18,
                  color: context.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                nav.targetSpeedText,
                style: TextStyle(fontSize: 14, color: context.textTertiary),
              ),
              if (nav.formattedEta != null) ...[
                const SizedBox(height: 8),
                Text(
                  'ETA: ${nav.formattedEta}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ],
            const Spacer(),
            // Target info card at the bottom.
            _TargetInfoCard(
              nav: nav,
              affiliationColor: affiliationColor,
              affiliationLabel: affiliation.label,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bearing compass widget
// ---------------------------------------------------------------------------

class _BearingCompass extends StatelessWidget {
  const _BearingCompass({
    required this.bearingDegrees,
    required this.affiliationColor,
  });

  final double bearingDegrees;
  final Color affiliationColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: CustomPaint(
        painter: _CompassPainter(
          bearingDegrees: bearingDegrees,
          arrowColor: affiliationColor,
          ringColor: context.textTertiary,
          labelColor: context.textSecondary,
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({
    required this.bearingDegrees,
    required this.arrowColor,
    required this.ringColor,
    required this.labelColor,
  });

  final double bearingDegrees;
  final Color arrowColor;
  final Color ringColor;
  final Color labelColor;

  static const _cardinals = ['N', 'E', 'S', 'W'];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer ring.
    final ringPaint = Paint()
      ..color = ringColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 4, ringPaint);

    // Degree tick marks at 30-degree intervals.
    final tickPaint = Paint()
      ..color = ringColor.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (var deg = 0; deg < 360; deg += 30) {
      final rad = (deg - 90) * math.pi / 180;
      final outerPoint = Offset(
        center.dx + (radius - 4) * math.cos(rad),
        center.dy + (radius - 4) * math.sin(rad),
      );
      final innerPoint = Offset(
        center.dx + (radius - 14) * math.cos(rad),
        center.dy + (radius - 14) * math.sin(rad),
      );
      canvas.drawLine(outerPoint, innerPoint, tickPaint);
    }

    // Cardinal labels (N, E, S, W).
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < 4; i++) {
      final deg = i * 90;
      final rad = (deg - 90) * math.pi / 180;
      final labelPos = Offset(
        center.dx + (radius - 26) * math.cos(rad),
        center.dy + (radius - 26) * math.sin(rad),
      );
      textPainter.text = TextSpan(
        text: _cardinals[i],
        style: TextStyle(
          color: labelColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          labelPos.dx - textPainter.width / 2,
          labelPos.dy - textPainter.height / 2,
        ),
      );
    }

    // Bearing arrow.
    final arrowRad = (bearingDegrees - 90) * math.pi / 180;
    final arrowTip = Offset(
      center.dx + (radius - 36) * math.cos(arrowRad),
      center.dy + (radius - 36) * math.sin(arrowRad),
    );
    final arrowBase = Offset(
      center.dx + 16 * math.cos(arrowRad),
      center.dy + 16 * math.sin(arrowRad),
    );

    // Line from center outward.
    final arrowPaint = Paint()
      ..color = arrowColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(arrowBase, arrowTip, arrowPaint);

    // Triangle tip.
    final perpRad = arrowRad + math.pi / 2;
    const tipHalfWidth = 8.0;
    const tipLength = 12.0;
    final tipEnd = Offset(
      center.dx + (radius - 36 + tipLength) * math.cos(arrowRad),
      center.dy + (radius - 36 + tipLength) * math.sin(arrowRad),
    );
    final tipLeft = Offset(
      arrowTip.dx - tipHalfWidth * math.cos(perpRad),
      arrowTip.dy - tipHalfWidth * math.sin(perpRad),
    );
    final tipRight = Offset(
      arrowTip.dx + tipHalfWidth * math.cos(perpRad),
      arrowTip.dy + tipHalfWidth * math.sin(perpRad),
    );

    final tipPath = Path()
      ..moveTo(tipEnd.dx, tipEnd.dy)
      ..lineTo(tipLeft.dx, tipLeft.dy)
      ..lineTo(tipRight.dx, tipRight.dy)
      ..close();
    canvas.drawPath(tipPath, Paint()..color = arrowColor);

    // Small center dot.
    canvas.drawCircle(center, 4, Paint()..color = arrowColor);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) =>
      bearingDegrees != oldDelegate.bearingDegrees ||
      arrowColor != oldDelegate.arrowColor;
}

// ---------------------------------------------------------------------------
// No position fallback
// ---------------------------------------------------------------------------

class _NoPositionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: context.card,
        shape: BoxShape.circle,
        border: Border.all(color: context.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 48, color: context.textTertiary),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Position unavailable\nConnect to a node with GPS',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: context.textTertiary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Target info card
// ---------------------------------------------------------------------------

class _TargetInfoCard extends StatelessWidget {
  const _TargetInfoCard({
    required this.nav,
    required this.affiliationColor,
    required this.affiliationLabel,
  });

  final TakNavigationState nav;
  final Color affiliationColor;
  final String affiliationLabel;

  @override
  Widget build(BuildContext context) {
    final target = nav.target;
    final icon = cotTypeIcon(target.type);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: affiliationColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  target.callsign ?? target.uid,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: affiliationColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  affiliationLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: affiliationColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Position',
            value:
                '${target.lat.toStringAsFixed(6)}, '
                '${target.lon.toStringAsFixed(6)}',
            context: context,
          ),
          const SizedBox(height: 4),
          _InfoRow(
            label: 'Last update',
            value: _formatAge(target.receivedUtcMs),
            context: context,
          ),
        ],
      ),
    );
  }

  static String _formatAge(int timestampMs) {
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(timestampMs),
    );
    if (age.inSeconds < 60) return '${age.inSeconds}s ago';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.context,
  });

  final String label;
  final String value;
  final BuildContext context;

  @override
  Widget build(BuildContext buildContext) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: buildContext.textTertiary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: buildContext.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
