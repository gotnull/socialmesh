// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Animated proximity indicator showing signal strength with 1-3 pulsing dots.
///
/// Based on hop count:
/// - 0 hops (direct): 3 dots - strongest, fastest pulse
/// - 1 hop: 2 dots - medium pulse
/// - 2+ hops or null: 1 dot - slowest pulse
///
/// The dots pulse with a glow effect, intensity based on proximity.
class ProximityIndicator extends StatefulWidget {
  const ProximityIndicator({
    super.key,
    this.hopCount,
    this.size = 6,
    this.spacing = 3,
  });

  /// Hop count from mesh. 0 = direct, 1 = 1 hop, etc.
  /// Null means unknown proximity (cloud-only signal).
  final int? hopCount;

  /// Size of each dot
  final double size;

  /// Spacing between dots
  final double spacing;

  @override
  State<ProximityIndicator> createState() => _ProximityIndicatorState();
}

class _ProximityIndicatorState extends State<ProximityIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  @override
  void didUpdateWidget(ProximityIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hopCount != widget.hopCount) {
      _setupAnimation();
    }
  }

  void _setupAnimation() {
    // Pulse speed based on proximity - closer = faster
    final duration = _getPulseDuration();

    _controller = AnimationController(vsync: this, duration: duration);

    _pulseAnimation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.repeat(reverse: true);
  }

  Duration _getPulseDuration() {
    final hopCount = widget.hopCount;
    if (hopCount == null) return const Duration(milliseconds: 1500);
    if (hopCount == 0) return const Duration(milliseconds: 600);
    if (hopCount == 1) return const Duration(milliseconds: 900);
    return const Duration(milliseconds: 1200);
  }

  int get _dotCount {
    final hopCount = widget.hopCount;
    if (hopCount == null) return 1;
    if (hopCount == 0) return 3;
    if (hopCount == 1) return 2;
    return 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;
    final dotCount = _dotCount;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final pulse = _pulseAnimation.value;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(dotCount, (index) {
            // Stagger the pulse for each dot
            final staggeredPulse = (pulse + (index * 0.15)).clamp(0.0, 1.0);

            return Padding(
              padding: EdgeInsets.only(left: index > 0 ? widget.spacing : 0),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(
                    alpha: 0.3 + (staggeredPulse * 0.7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(
                        alpha: staggeredPulse * 0.6,
                      ),
                      blurRadius: widget.size * staggeredPulse,
                      spreadRadius: widget.size * 0.2 * staggeredPulse,
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Compact proximity badge showing dots with "nearby" label.
/// Replaces the old static "nearby" badge.
class ProximityBadge extends StatelessWidget {
  const ProximityBadge({super.key, this.hopCount});

  final int? hopCount;

  String get _label {
    final hops = hopCount;
    if (hops == null) return 'nearby';
    if (hops == 0) return 'direct';
    if (hops == 1) return '1 hop';
    return '$hops hops';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProximityIndicator(hopCount: hopCount, size: 5, spacing: 2),
          const SizedBox(width: 5),
          Text(
            _label,
            style: TextStyle(
              color: context.accentColor,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
