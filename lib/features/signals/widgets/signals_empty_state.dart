import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';

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
  late Ticker _floatTicker;
  double _floatTime = 0.0;
  late List<_FloatingNode> _floatingNodes;
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSub;
  Offset _tiltTarget = Offset.zero;
  Offset _tiltOffset = Offset.zero;
  Offset _gyroOffset = Offset.zero;
  int _tiltStabilizationFrames = 0;
  static const int _tiltStabilizationDelay = 30;
  static const double _tiltSmoothing = 0.9;
  static const double _tiltAmplitude = 14.0;
  static const double _gyroSensitivity = 2.0;
  static const double _gyroFriction = 0.94;
  static const double _gyroMax = 12.0;

  @override
  void initState() {
    super.initState();

    // Radar pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Floating nodes animation
    _floatTicker = createTicker((elapsed) {
      _floatTime = elapsed.inMilliseconds / 3000.0;
      _tiltOffset =
          _tiltOffset * _tiltSmoothing + _tiltTarget * (1 - _tiltSmoothing);
      _gyroOffset = _gyroOffset * _gyroFriction;
      if (mounted) {
        setState(() {});
      }
    })..start();

    _accelerometerSub =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 16),
        ).listen((event) {
          if (!mounted) return;
          _updateTilt(event.x, event.y);
        });
    _gyroscopeSub =
        gyroscopeEventStream(
          samplingPeriod: const Duration(milliseconds: 16),
        ).listen((event) {
          if (!mounted) return;
          _updateGyro(event.x, event.y);
        });

    // Generate random floating nodes
    final random = Random();
    _floatingNodes = List.generate(9, (index) {
      return _FloatingNode(
        angle: random.nextDouble() * 2 * pi,
        radius: 60 + random.nextDouble() * 40,
        speed: 0.25 + random.nextDouble() * 0.35,
        size: 8 + random.nextDouble() * 8,
        opacity: 0.2 + random.nextDouble() * 0.3,
        wobble: 0.08 + random.nextDouble() * 0.12,
        wobbleSpeed: 0.4 + random.nextDouble() * 0.6,
        sweep: 0.6 + random.nextDouble() * 0.6,
      );
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatTicker.dispose();
    _accelerometerSub?.cancel();
    _gyroscopeSub?.cancel();
    super.dispose();
  }

  void _updateTilt(double accelX, double accelY) {
    if (_tiltStabilizationFrames < _tiltStabilizationDelay) {
      _tiltStabilizationFrames++;
      return;
    }

    final normalizedX = (accelX / 10.0).clamp(-1.0, 1.0);
    final normalizedY = (accelY / 10.0).clamp(-1.0, 1.0);
    _tiltTarget = Offset(
      normalizedX * _tiltAmplitude,
      normalizedY * _tiltAmplitude,
    );
  }

  void _updateGyro(double gyroX, double gyroY) {
    _gyroOffset += Offset(gyroY, gyroX) * _gyroSensitivity;
    _gyroOffset = _clampOffset(_gyroOffset, -_gyroMax, _gyroMax);
  }

  Offset _clampOffset(Offset value, double min, double max) {
    return Offset(value.dx.clamp(min, max), value.dy.clamp(min, max));
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

                  // Floating nodes (above center icon)
                  Stack(
                    alignment: Alignment.center,
                    children: _floatingNodes.map((node) {
                      final oscillation = sin(_floatTime * 2 * pi * node.speed);
                      final angle = node.angle + (oscillation * node.sweep);
                      final wobblePhase =
                          _floatTime * 2 * pi * node.wobbleSpeed;
                      final radius =
                          node.radius *
                          (1 + sin(wobblePhase + node.angle) * node.wobble);
                      final depthScale = 0.4 + (node.radius / 140);
                      final parallax =
                          _tiltOffset + (_gyroOffset * 0.4);
                      final x = cos(angle) * radius + parallax.dx * depthScale;
                      final y = sin(angle) * radius + parallax.dy * depthScale;
                      return Transform.translate(
                        offset: Offset(x, y),
                        child: Container(
                          width: node.size,
                          height: node.size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: node.opacity),
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
  final double wobble;
  final double wobbleSpeed;
  final double sweep;

  _FloatingNode({
    required this.angle,
    required this.radius,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.wobble,
    required this.wobbleSpeed,
    required this.sweep,
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
