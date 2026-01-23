import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animated_tagline.dart';

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

const _signalEmptyTaglines = [
  'Nothing active here right now.\nSignals appear when someone nearby goes active.',
  'Signals are mesh-first and ephemeral.\nThey dissolve when their timer ends.',
  'Share a quick status or photo.\nNearby nodes will see it in real time.',
  'Go active to broadcast your presence.\nOff-grid, device to device.',
];

class _SignalsEmptyStateState extends State<SignalsEmptyState>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _convergeController;
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

    _convergeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

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
    final palette = AccentColors.gradients
        .map((gradient) => gradient[random.nextInt(gradient.length)])
        .toList();
    _floatingNodes = List.generate(palette.length, (index) {
      final isSoft = random.nextDouble() < 0.35;
      return _FloatingNode(
        angle: random.nextDouble() * 2 * pi,
        radius: 30 + random.nextDouble() * 80,
        speed: 0.25 + random.nextDouble() * 0.35,
        size: 8 + random.nextDouble() * 8,
        opacity: isSoft
            ? 0.14 + random.nextDouble() * 0.16
            : 0.2 + random.nextDouble() * 0.3,
        wobble: 0.08 + random.nextDouble() * 0.12,
        wobbleSpeed: 0.4 + random.nextDouble() * 0.6,
        sweep: 0.6 + random.nextDouble() * 0.6,
        color: palette[index],
        phaseOffset: random.nextDouble() * 2 * pi,
        blurSigma: isSoft ? 6 + random.nextDouble() * 6 : 0,
      );
    });

    if (widget.canGoActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HapticFeedback.selectionClick();
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _convergeController.dispose();
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

  void _triggerConverge() {
    if (_convergeController.isAnimating) return;
    _convergeController.forward(from: 0).then((_) {
      if (mounted) {
        _convergeController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;
    final activityFactor = widget.canGoActive ? 1.0 : 0.7;

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
                  // Breathing field
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final breathe = 0.9 + (_pulseController.value * 0.15);
                      final alpha = 0.08 + (_pulseController.value * 0.08);
                      return Transform.scale(
                        scale: breathe,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                accentColor.withValues(alpha: alpha),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.7],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
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
                  AnimatedBuilder(
                    animation: _convergeController,
                    builder: (context, child) {
                      final converge =
                          1 - (_convergeController.value * 0.25);
                      return Stack(
                        alignment: Alignment.center,
                        children: _floatingNodes.map((node) {
                          final oscillation = sin(
                            _floatTime * 2 * pi * node.speed * activityFactor +
                                node.phaseOffset,
                          );
                          final angle = node.angle + (oscillation * node.sweep);
                          final wobblePhase =
                              _floatTime * 2 * pi * node.wobbleSpeed +
                              node.phaseOffset;
                          final radius =
                              node.radius *
                              converge *
                              (1 + sin(wobblePhase + node.angle) * node.wobble);
                          final depthScale = 0.4 + (node.radius / 140);
                          final parallax =
                              (_tiltOffset + (_gyroOffset * 0.4)) *
                                  activityFactor;
                          final x =
                              cos(angle) * radius + parallax.dx * depthScale;
                          final y =
                              sin(angle) * radius + parallax.dy * depthScale;
                          final opacity =
                              node.opacity * (widget.canGoActive ? 1.0 : 0.6);

                          Widget orb = Container(
                            width: node.size,
                            height: node.size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: node.color.withValues(alpha: opacity),
                              boxShadow: [
                                BoxShadow(
                                  color: node.color.withValues(
                                    alpha: opacity * 0.5,
                                  ),
                                  blurRadius: node.size,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          );

                          if (node.blurSigma > 0) {
                            orb = ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: node.blurSigma,
                                sigmaY: node.blurSigma,
                              ),
                              child: orb,
                            );
                          }

                          return Transform.translate(
                            offset: Offset(x, y),
                            child: orb,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Builder(
              builder: (context) {
                final baseStyle = TextStyle(
                  color: context.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                );
                final gradient = LinearGradient(
                  colors: AccentColors.gradientFor(context.accentColor),
                );
                return RichText(
                  text: TextSpan(
                    style: baseStyle,
                    children: [
                      const TextSpan(text: 'No active '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: ShaderMask(
                          shaderCallback: (rect) =>
                              gradient.createShader(rect),
                          child: Text(
                            'signals',
                            style: baseStyle.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: ' nearby'),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            SizedBox(
              height: 80,
              child: Center(
                child: AnimatedTagline(
                  taglines: _signalEmptyTaglines,
                  textStyle: TextStyle(color: context.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Go Active button
            _GoActiveButton(
              canGoActive: widget.canGoActive,
              blockedReason: widget.blockedReason,
              onTap: () {
                _triggerConverge();
                widget.onGoActive();
              },
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
  final Color color;
  final double phaseOffset;
  final double blurSigma;

  _FloatingNode({
    required this.angle,
    required this.radius,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.wobble,
    required this.wobbleSpeed,
    required this.sweep,
    required this.color,
    required this.phaseOffset,
    required this.blurSigma,
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
