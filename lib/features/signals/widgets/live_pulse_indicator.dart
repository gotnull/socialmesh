import 'package:flutter/material.dart';

/// A pulsing indicator to show live/recent activity
class LivePulseIndicator extends StatefulWidget {
  const LivePulseIndicator({
    this.color,
    this.size = 12,
    this.pulseScale = 2.0,
    super.key,
  });

  final Color? color;
  final double size;
  final double pulseScale;

  @override
  State<LivePulseIndicator> createState() => _LivePulseIndicatorState();
}

class _LivePulseIndicatorState extends State<LivePulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pulseScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: widget.size * widget.pulseScale,
      height: widget.size * widget.pulseScale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse ring
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                  ),
                ),
              );
            },
          ),
          // Center dot
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A wrapper that adds a pulse indicator to a widget based on a condition
class LivePulseWrapper extends StatelessWidget {
  const LivePulseWrapper({
    required this.child,
    required this.isLive,
    this.position = LivePulsePosition.topRight,
    this.color,
    this.size = 10,
    super.key,
  });

  final Widget child;
  final bool isLive;
  final LivePulsePosition position;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!isLive) return child;

    Alignment alignment;
    EdgeInsets padding;

    switch (position) {
      case LivePulsePosition.topLeft:
        alignment = Alignment.topLeft;
        padding = const EdgeInsets.only(left: 4, top: 4);
      case LivePulsePosition.topRight:
        alignment = Alignment.topRight;
        padding = const EdgeInsets.only(right: 4, top: 4);
      case LivePulsePosition.bottomLeft:
        alignment = Alignment.bottomLeft;
        padding = const EdgeInsets.only(left: 4, bottom: 4);
      case LivePulsePosition.bottomRight:
        alignment = Alignment.bottomRight;
        padding = const EdgeInsets.only(right: 4, bottom: 4);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned.fill(
          child: Align(
            alignment: alignment,
            child: Padding(
              padding: padding,
              child: LivePulseIndicator(color: color, size: size),
            ),
          ),
        ),
      ],
    );
  }
}

enum LivePulsePosition { topLeft, topRight, bottomLeft, bottomRight }

/// Utility to check if a signal is "live" (recent activity)
bool isSignalLive(
  DateTime? lastActivity, {
  Duration threshold = const Duration(minutes: 5),
}) {
  if (lastActivity == null) return false;
  return DateTime.now().difference(lastActivity) < threshold;
}
