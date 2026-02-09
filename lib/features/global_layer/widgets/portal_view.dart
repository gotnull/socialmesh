// SPDX-License-Identifier: GPL-3.0-or-later

/// Portal View — animated visualization of local mesh → broker → remote mesh
/// traffic flow for the Global Layer feature.
///
/// Shows three columns:
/// - Local Mesh (left) — your connected mesh nodes
/// - Broker Portal (center) — the MQTT broker relay
/// - Remote Meshes (right) — other meshes connected to the same broker
///
/// Animated particles flow between the columns to represent message
/// traffic. Respects Reduce Motion preference with a static fallback.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mqtt/mqtt_connection_state.dart';
import '../../../core/mqtt/mqtt_metrics.dart';
import '../../../core/theme.dart';
import '../../../providers/accessibility_providers.dart';
import '../../../providers/mqtt_providers.dart';

/// Compact portal visualization showing traffic flow direction and
/// connection state at a glance.
///
/// This widget is designed to sit at the top of the Topic Explorer
/// screen or as a card in the Status screen. It adapts to the current
/// [GlobalLayerConnectionState] and [GlobalLayerMetrics].
///
/// Usage:
/// ```dart
/// const PortalView(height: 160)
/// ```
class PortalView extends ConsumerStatefulWidget {
  /// The total height of the portal visualization.
  final double height;

  const PortalView({super.key, this.height = 160});

  @override
  ConsumerState<PortalView> createState() => _PortalViewState();
}

class _PortalViewState extends ConsumerState<PortalView>
    with TickerProviderStateMixin {
  late final AnimationController _flowController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(globalLayerConnectionStateProvider);
    final metrics = ref.watch(globalLayerMetricsProvider);
    final reduceMotion = ref.watch(reduceMotionEnabledProvider);

    // Pause animations when not connected or reduce motion is on
    if (reduceMotion || !connectionState.isActive) {
      if (_flowController.isAnimating) _flowController.stop();
      if (_pulseController.isAnimating) _pulseController.stop();
    } else {
      if (!_flowController.isAnimating) _flowController.repeat();
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    }

    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background gradient
            _PortalBackground(
              connectionState: connectionState,
              pulseController: _pulseController,
              reduceMotion: reduceMotion,
            ),

            // Flow particles (only when active)
            if (connectionState.isActive && !reduceMotion)
              _FlowParticles(flowController: _flowController, metrics: metrics),

            // Static flow arrows for reduce motion
            if (connectionState.isActive && reduceMotion)
              const _StaticFlowIndicators(),

            // Three-column layout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Local Mesh
                  Expanded(
                    child: _PortalNode(
                      icon: Icons.cell_tower,
                      label: 'Local Mesh',
                      sublabel: _localSublabel(connectionState),
                      color: _localColor(connectionState),
                      isActive: connectionState.isActive,
                      pulseController: _pulseController,
                      reduceMotion: reduceMotion,
                    ),
                  ),

                  // Connection line left
                  _ConnectionLine(
                    connectionState: connectionState,
                    flowController: _flowController,
                    reduceMotion: reduceMotion,
                  ),

                  // Broker Portal
                  Expanded(
                    child: _PortalNode(
                      icon: Icons.cloud_outlined,
                      label: 'Broker',
                      sublabel: _brokerSublabel(connectionState),
                      color: connectionState.statusColor,
                      isActive: connectionState.isActive,
                      pulseController: _pulseController,
                      reduceMotion: reduceMotion,
                      isBroker: true,
                    ),
                  ),

                  // Connection line right
                  _ConnectionLine(
                    connectionState: connectionState,
                    flowController: _flowController,
                    reduceMotion: reduceMotion,
                    isReversed: true,
                  ),

                  // Remote Meshes
                  Expanded(
                    child: _PortalNode(
                      icon: Icons.language,
                      label: 'Remote',
                      sublabel: _remoteSublabel(connectionState, metrics),
                      color: _remoteColor(connectionState),
                      isActive: connectionState.isActive,
                      pulseController: _pulseController,
                      reduceMotion: reduceMotion,
                    ),
                  ),
                ],
              ),
            ),

            // Throughput overlay
            if (connectionState.isActive)
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: _ThroughputBar(metrics: metrics),
              ),
          ],
        ),
      ),
    );
  }

  String _localSublabel(GlobalLayerConnectionState state) {
    return switch (state) {
      GlobalLayerConnectionState.connected => 'Bridged',
      GlobalLayerConnectionState.degraded => 'Partial',
      GlobalLayerConnectionState.connecting => 'Linking...',
      GlobalLayerConnectionState.reconnecting => 'Restoring...',
      _ => 'Offline',
    };
  }

  String _brokerSublabel(GlobalLayerConnectionState state) {
    return switch (state) {
      GlobalLayerConnectionState.connected => 'Active',
      GlobalLayerConnectionState.degraded => 'Issues',
      GlobalLayerConnectionState.connecting => 'Reaching...',
      GlobalLayerConnectionState.reconnecting => 'Retrying...',
      GlobalLayerConnectionState.disconnecting => 'Closing...',
      _ => 'Idle',
    };
  }

  String _remoteSublabel(
    GlobalLayerConnectionState state,
    GlobalLayerMetrics metrics,
  ) {
    if (!state.isActive) return 'Unavailable';
    final inbound = metrics.totalInbound;
    if (inbound > 0) return '$inbound received';
    return 'Listening';
  }

  Color _localColor(GlobalLayerConnectionState state) {
    return switch (state) {
      GlobalLayerConnectionState.connected => const Color(0xFF4ADE80),
      GlobalLayerConnectionState.degraded => const Color(0xFFFF9D6E),
      _ => const Color(0xFF9CA3AF),
    };
  }

  Color _remoteColor(GlobalLayerConnectionState state) {
    return switch (state) {
      GlobalLayerConnectionState.connected => const Color(0xFF60A5FA),
      GlobalLayerConnectionState.degraded => const Color(0xFFFBBF24),
      _ => const Color(0xFF9CA3AF),
    };
  }
}

// =============================================================================
// Portal Node — icon + label column
// =============================================================================

class _PortalNode extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final bool isActive;
  final AnimationController pulseController;
  final bool reduceMotion;
  final bool isBroker;

  const _PortalNode({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.isActive,
    required this.pulseController,
    required this.reduceMotion,
    this.isBroker = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(
          color: color.withValues(alpha: isActive ? 0.6 : 0.2),
          width: isBroker ? 2 : 1.5,
        ),
      ),
      child: Icon(icon, size: 22, color: color),
    );

    // Add pulse animation for the broker when active
    if (isActive && isBroker && !reduceMotion) {
      iconWidget = AnimatedBuilder(
        animation: pulseController,
        builder: (context, child) {
          final scale = 1.0 + (pulseController.value * 0.06);
          return Transform.scale(scale: scale, child: child);
        },
        child: iconWidget,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          sublabel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color.withValues(alpha: 0.9),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// =============================================================================
// Connection Line — dashed line between nodes with directional animation
// =============================================================================

class _ConnectionLine extends StatelessWidget {
  final GlobalLayerConnectionState connectionState;
  final AnimationController flowController;
  final bool reduceMotion;
  final bool isReversed;

  const _ConnectionLine({
    required this.connectionState,
    required this.flowController,
    required this.reduceMotion,
    this.isReversed = false,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = connectionState.isActive;
    final color = isActive
        ? connectionState.statusColor.withValues(alpha: 0.5)
        : context.border;

    if (reduceMotion || !isActive) {
      // Static dashed line
      return SizedBox(
        width: 32,
        height: 2,
        child: CustomPaint(
          painter: _DashedLinePainter(color: color, dashWidth: 4, gap: 3),
        ),
      );
    }

    return AnimatedBuilder(
      animation: flowController,
      builder: (context, _) {
        return SizedBox(
          width: 32,
          height: 2,
          child: CustomPaint(
            painter: _AnimatedDashedLinePainter(
              color: connectionState.statusColor.withValues(alpha: 0.6),
              progress: isReversed
                  ? 1.0 - flowController.value
                  : flowController.value,
              dashWidth: 4,
              gap: 3,
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Dashed Line Painters
// =============================================================================

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double gap;

  _DashedLinePainter({
    required this.color,
    required this.dashWidth,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;

    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dashWidth).clamp(0, size.width), size.height / 2),
        paint,
      );
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) =>
      old.color != color || old.dashWidth != dashWidth || old.gap != gap;
}

class _AnimatedDashedLinePainter extends CustomPainter {
  final Color color;
  final double progress;
  final double dashWidth;
  final double gap;

  _AnimatedDashedLinePainter({
    required this.color,
    required this.progress,
    required this.dashWidth,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;

    final cycleLength = dashWidth + gap;
    final offset = progress * cycleLength;

    double x = -cycleLength + offset;
    while (x < size.width + cycleLength) {
      // Vary opacity along the line for a flowing effect
      final normalizedX = (x / size.width).clamp(0.0, 1.0);
      final waveAlpha = 0.3 + 0.7 * math.sin(normalizedX * math.pi);
      paint.color = color.withValues(alpha: waveAlpha);

      final startX = x.clamp(0.0, size.width);
      final endX = (x + dashWidth).clamp(0.0, size.width);
      if (endX > startX) {
        canvas.drawLine(
          Offset(startX, size.height / 2),
          Offset(endX, size.height / 2),
          paint,
        );
      }
      x += cycleLength;
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedDashedLinePainter old) =>
      old.progress != progress || old.color != color;
}

// =============================================================================
// Flow Particles — animated dots flowing between columns
// =============================================================================

class _FlowParticles extends StatelessWidget {
  final AnimationController flowController;
  final GlobalLayerMetrics metrics;

  const _FlowParticles({required this.flowController, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: flowController,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _FlowParticlesPainter(
            progress: flowController.value,
            outboundCount: metrics.totalOutbound.clamp(0, 5),
            inboundCount: metrics.totalInbound.clamp(0, 5),
            accentColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.6),
            inboundColor: const Color(0xFF60A5FA).withValues(alpha: 0.6),
          ),
        );
      },
    );
  }
}

class _FlowParticlesPainter extends CustomPainter {
  final double progress;
  final int outboundCount;
  final int inboundCount;
  final Color accentColor;
  final Color inboundColor;

  _FlowParticlesPainter({
    required this.progress,
    required this.outboundCount,
    required this.inboundCount,
    required this.accentColor,
    required this.inboundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final leftX = size.width * 0.2;
    final rightX = size.width * 0.8;
    final midX = size.width * 0.5;

    // Outbound particles (local → broker)
    _drawParticleStream(
      canvas: canvas,
      startX: leftX,
      endX: midX,
      y: centerY - 4,
      progress: progress,
      count: outboundCount.clamp(1, 3),
      color: accentColor,
      radius: 2.5,
    );

    // Inbound particles (broker → local)
    _drawParticleStream(
      canvas: canvas,
      startX: midX,
      endX: leftX,
      y: centerY + 4,
      progress: progress,
      count: inboundCount.clamp(1, 3),
      color: inboundColor,
      radius: 2.0,
    );

    // Broker → remote (mirrored outbound)
    _drawParticleStream(
      canvas: canvas,
      startX: midX,
      endX: rightX,
      y: centerY - 4,
      progress: progress,
      count: outboundCount.clamp(1, 3),
      color: accentColor.withValues(alpha: 0.4),
      radius: 2.0,
    );

    // Remote → broker (mirrored inbound)
    _drawParticleStream(
      canvas: canvas,
      startX: rightX,
      endX: midX,
      y: centerY + 4,
      progress: progress,
      count: inboundCount.clamp(1, 3),
      color: inboundColor.withValues(alpha: 0.4),
      radius: 2.0,
    );
  }

  void _drawParticleStream({
    required Canvas canvas,
    required double startX,
    required double endX,
    required double y,
    required double progress,
    required int count,
    required Color color,
    required double radius,
  }) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final offset = (i / count);
      final t = (progress + offset) % 1.0;
      final x = startX + (endX - startX) * t;

      // Fade in and out at edges
      final edgeFade = _edgeFade(t);
      paint.color = color.withValues(alpha: edgeFade * 0.8);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  double _edgeFade(double t) {
    if (t < 0.1) return t / 0.1;
    if (t > 0.9) return (1.0 - t) / 0.1;
    return 1.0;
  }

  @override
  bool shouldRepaint(covariant _FlowParticlesPainter old) =>
      old.progress != progress ||
      old.outboundCount != outboundCount ||
      old.inboundCount != inboundCount;
}

// =============================================================================
// Static Flow Indicators — for Reduce Motion preference
// =============================================================================

class _StaticFlowIndicators extends StatelessWidget {
  const _StaticFlowIndicators();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _StaticArrowPainter(
          color: context.accentColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _StaticArrowPainter extends CustomPainter {
  final Color color;

  _StaticArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final leftX = size.width * 0.28;
    final midX = size.width * 0.5;
    final rightX = size.width * 0.72;

    // Left → Center arrow
    _drawArrow(canvas, paint, leftX, centerY - 2, midX - 8, centerY - 2);
    // Center → Right arrow
    _drawArrow(canvas, paint, midX + 8, centerY - 2, rightX, centerY - 2);

    // Center → Left arrow (below)
    _drawArrow(canvas, paint, midX - 8, centerY + 6, leftX, centerY + 6);
    // Right → Center arrow (below)
    _drawArrow(canvas, paint, rightX, centerY + 6, midX + 8, centerY + 6);
  }

  void _drawArrow(
    Canvas canvas,
    Paint paint,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);

    // Arrowhead
    final direction = (x2 - x1).sign;
    final arrowSize = 4.0;
    canvas.drawLine(
      Offset(x2, y2),
      Offset(x2 - direction * arrowSize, y2 - arrowSize),
      paint,
    );
    canvas.drawLine(
      Offset(x2, y2),
      Offset(x2 - direction * arrowSize, y2 + arrowSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _StaticArrowPainter old) => old.color != color;
}

// =============================================================================
// Portal Background — subtle gradient backdrop
// =============================================================================

class _PortalBackground extends StatelessWidget {
  final GlobalLayerConnectionState connectionState;
  final AnimationController pulseController;
  final bool reduceMotion;

  const _PortalBackground({
    required this.connectionState,
    required this.pulseController,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = connectionState.statusColor;
    final isDark = context.isDarkMode;

    if (reduceMotion || !connectionState.isActive) {
      return Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              baseColor.withValues(alpha: isDark ? 0.06 : 0.04),
              Colors.transparent,
            ],
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, _) {
        final alpha = 0.04 + (pulseController.value * 0.03);
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0 + (pulseController.value * 0.2),
              colors: [
                baseColor.withValues(alpha: alpha),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Throughput Bar — shows message rates at the bottom
// =============================================================================

class _ThroughputBar extends StatelessWidget {
  final GlobalLayerMetrics metrics;

  const _ThroughputBar({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final inRate = metrics.inboundRate;
    final outRate = metrics.outboundRate;
    final hasTraffic = inRate > 0 || outRate > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Outbound
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_upward,
                size: 10,
                color: hasTraffic ? context.accentColor : context.textTertiary,
              ),
              const SizedBox(width: 2),
              Text(
                _formatRate(outRate),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: hasTraffic
                      ? context.textSecondary
                      : context.textTertiary,
                  fontSize: 9,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),

          // Total
          Text(
            '${metrics.totalMessages} msgs',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.textTertiary,
              fontSize: 9,
              fontFamily: AppTheme.fontFamily,
            ),
          ),

          // Inbound
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_downward,
                size: 10,
                color: hasTraffic
                    ? const Color(0xFF60A5FA)
                    : context.textTertiary,
              ),
              const SizedBox(width: 2),
              Text(
                _formatRate(inRate),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: hasTraffic
                      ? context.textSecondary
                      : context.textTertiary,
                  fontSize: 9,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatRate(double rate) {
    if (rate <= 0) return '0/min';
    if (rate < 1) return '<1/min';
    return '${rate.toStringAsFixed(0)}/min';
  }
}
