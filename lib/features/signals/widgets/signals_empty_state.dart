import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Animated empty state for the signals screen.
/// Shows radar pulse rings and floating mesh icons.
class SignalsEmptyState extends StatefulWidget {
  const SignalsEmptyState({
    super.key,
    required this.canGoActive,
    required this.blockedReason,
    required this.onGoActive,
  });

  final bool canGoActive;
  final String? blockedReason;
  final VoidCallback onGoActive;

  @override
  State<SignalsEmptyState> createState() => _SignalsEmptyStateState();
}

class _SignalsEmptyStateState extends State<SignalsEmptyState>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late List<_FloatingNode> _floatingNodes;

  @override
  void initState() {
    super.initState();

    // Radar pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Floating nodes animation
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Generate random floating nodes
    final random = Random();
    _floatingNodes = List.generate(5, (index) {
      return _FloatingNode(
        angle: random.nextDouble() * 2 * pi,
        radius: 60 + random.nextDouble() * 40,
        speed: 0.3 + random.nextDouble() * 0.4,
        size: 8 + random.nextDouble() * 8,
        opacity: 0.2 + random.nextDouble() * 0.3,
      );
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated radar with floating nodes
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse rings
                  ...List.generate(3, (index) {
                    return AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final delay = index * 0.33;
                        final progress =
                            ((_pulseController.value + delay) % 1.0);
                        final opacity = (1.0 - progress) * 0.4;
                        final scale = 0.3 + (progress * 0.7);

                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accentColor.withValues(alpha: opacity),
                                width: 1.5,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),

                  // Floating nodes
                  AnimatedBuilder(
                    animation: _floatController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: _floatingNodes.map((node) {
                          final angle =
                              node.angle +
                              (_floatController.value * 2 * pi * node.speed);
                          final x = cos(angle) * node.radius;
                          final y = sin(angle) * node.radius;

                          return Transform.translate(
                            offset: Offset(x, y),
                            child: Container(
                              width: node.size,
                              height: node.size,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor.withValues(
                                  alpha: node.opacity,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(
                                      alpha: node.opacity * 0.5,
                                    ),
                                    blurRadius: node.size,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  // Center icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.card,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.sensors_off,
                      size: 48,
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'No active signals nearby',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Nothing active here right now.\nWhen someone nearby goes active, it will appear here.',
              style: TextStyle(color: context.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Go Active button
            _GoActiveButton(
              canGoActive: widget.canGoActive,
              blockedReason: widget.blockedReason,
              onTap: widget.onGoActive,
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingNode {
  final double angle;
  final double radius;
  final double speed;
  final double size;
  final double opacity;

  _FloatingNode({
    required this.angle,
    required this.radius,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}

/// Animated "Go Active" button with gradient and pulse effect
class _GoActiveButton extends StatefulWidget {
  const _GoActiveButton({
    required this.canGoActive,
    required this.blockedReason,
    required this.onTap,
  });

  final bool canGoActive;
  final String? blockedReason;
  final VoidCallback onTap;

  @override
  State<_GoActiveButton> createState() => _GoActiveButtonState();
}

class _GoActiveButtonState extends State<_GoActiveButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.canGoActive) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_GoActiveButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.canGoActive != oldWidget.canGoActive) {
      if (widget.canGoActive) {
        _glowController.repeat(reverse: true);
      } else {
        _glowController.stop();
        _glowController.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;
    final gradientColors = AccentColors.gradientFor(accentColor);
    final gradient = LinearGradient(colors: gradientColors);

    return Tooltip(
      message: widget.blockedReason ?? '',
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final glowIntensity = widget.canGoActive
                ? _glowController.value * 0.3
                : 0.0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: widget.canGoActive ? gradient : null,
                color: widget.canGoActive
                    ? null
                    : context.border.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
                boxShadow: widget.canGoActive
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(
                            alpha: 0.3 + glowIntensity,
                          ),
                          blurRadius: 12 + (glowIntensity * 8),
                          spreadRadius: glowIntensity * 4,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sensors,
                    color: widget.canGoActive
                        ? Colors.white
                        : context.textTertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Go Active',
                    style: TextStyle(
                      color: widget.canGoActive
                          ? Colors.white
                          : context.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
