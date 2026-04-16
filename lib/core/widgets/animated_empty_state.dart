// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../theme.dart';
import 'animated_tagline.dart';
import 'animated_gradient_mask.dart';
import 'animated_gradient_background.dart';

/// Configuration for the animated empty state.
class AnimatedEmptyStateConfig {
  /// Icons to cycle through in the center radar
  final List<IconData> icons;

  /// Taglines to cycle through below the title
  final List<String> taglines;

  /// The main title with a gradient-animated keyword
  /// e.g., "No active signals nearby" where "signals" is animated
  final String titlePrefix;
  final String titleKeyword;
  final String titleSuffix;

  /// Optional action button configuration
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// Whether the action is enabled (e.g., can go active)
  final bool actionEnabled;

  /// Optional tooltip for disabled action
  final String? actionDisabledReason;

  /// Optional override color for the accent (defaults to context.accentColor)
  final Color? accentColor;

  const AnimatedEmptyStateConfig({
    required this.icons,
    required this.taglines,
    required this.titlePrefix,
    required this.titleKeyword,
    required this.titleSuffix,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.actionEnabled = true,
    this.actionDisabledReason,
    this.accentColor,
  });
}

/// Animated empty state with radar pulse, floating particles, cycling icons,
/// gradient text, and optional action button.
///
/// This is the standardized empty state pattern used across Social screens
/// (Signals, Presence, Activity, NodeDex, etc.)
class AnimatedEmptyState extends StatefulWidget {
  final AnimatedEmptyStateConfig config;

  const AnimatedEmptyState({super.key, required this.config});

  @override
  State<AnimatedEmptyState> createState() => _AnimatedEmptyStateState();
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

class _AnimatedEmptyStateState extends State<AnimatedEmptyState>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late AnimationController _convergeController;
  late AnimationController _floatController;
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
  static const double _iconSize = 48.0;
  bool _reduceMotion = false;

  /// Sensor sampling period. 50ms (20Hz) is sufficient for smooth parallax
  /// tilt effects while using ~68% less CPU than the previous 16ms (62.5Hz).
  static const Duration _sensorSamplingPeriod = Duration(milliseconds: 50);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Radar pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _convergeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    // Floating nodes animation driven by AnimationController instead of a raw
    // Ticker + setState. The controller's value linearly sweeps 0→1 over 3s
    // and repeats. The listener updates tilt/gyro interpolation state but does
    // NOT call setState -- rebuilds are handled by AnimatedBuilder in the tree.
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..addListener(_onFloatTick);

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

    if (widget.config.actionEnabled && widget.config.onAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HapticFeedback.selectionClick();
      });
    }
  }

  /// Listener for `_floatController`. Updates the cumulative float time from
  /// the controller's elapsed duration and interpolates tilt/gyro offsets each
  /// frame. No `setState` -- the `AnimatedBuilder` in the widget tree observes
  /// `_floatController` directly and triggers a rebuild/repaint only within
  /// its isolated subtree.
  void _onFloatTick() {
    final elapsed = _floatController.lastElapsedDuration;
    if (elapsed != null) {
      _floatTime = elapsed.inMilliseconds / 3000.0;
    }
    _tiltOffset =
        _tiltOffset * _tiltSmoothing + _tiltTarget * (1 - _tiltSmoothing);
    _gyroOffset = _gyroOffset * _gyroFriction;
  }

  void _startSensors() {
    if (_reduceMotion || defaultTargetPlatform == TargetPlatform.macOS) {
      return;
    }
    _accelerometerSub ??=
        accelerometerEventStream(samplingPeriod: _sensorSamplingPeriod).listen((
          event,
        ) {
          _updateTilt(event.x, event.y);
        });
    _gyroscopeSub ??=
        gyroscopeEventStream(samplingPeriod: _sensorSamplingPeriod).listen((
          event,
        ) {
          _updateGyro(event.x, event.y);
        });
  }

  void _stopSensors() {
    _accelerometerSub?.cancel();
    _accelerometerSub = null;
    _gyroscopeSub?.cancel();
    _gyroscopeSub = null;
  }

  void _syncMotionState({bool force = false}) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!force && reduceMotion == _reduceMotion) {
      return;
    }
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _pulseController.stop();
      _pulseController.value = 0.0;
      _floatController.stop();
      _floatController.value = 0.0;
      _convergeController.stop();
      _convergeController.value = 0.0;
      _floatTime = 0.0;
      _tiltTarget = Offset.zero;
      _tiltOffset = Offset.zero;
      _gyroOffset = Offset.zero;
      _stopSensors();
      return;
    }
    if (!_pulseController.isAnimating) {
      _pulseController.repeat();
    }
    if (!_floatController.isAnimating) {
      _floatController.repeat();
    }
    _startSensors();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotionState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // Stop sensor delivery when the app is not in the foreground.
        // sensors_plus fires CoreMotion callbacks on a background thread;
        // if the Flutter engine tears down before the subscription is
        // cancelled the native thunk crashes with NSInternalInconsistencyException.
        _stopSensors();
        return;
      case AppLifecycleState.resumed:
      case AppLifecycleState.hidden:
        _startSensors();
        return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _convergeController.dispose();
    _floatController.dispose();
    _stopSensors();
    super.dispose();
  }

  Widget _buildGradientIcon(
    BuildContext context,
    IconData icon, {
    bool animate = true,
  }) {
    final accentColor = widget.config.accentColor ?? context.accentColor;
    final gradient = LinearGradient(
      colors: AccentColors.gradientFor(accentColor),
    );
    return AnimatedGradientMask(
      gradient: gradient,
      animate: animate,
      child: Icon(icon, size: _iconSize, color: Colors.white),
    );
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
    if (_reduceMotion) return;
    if (_convergeController.isAnimating) return;
    _convergeController.forward(from: 0).then((_) {
      if (mounted) {
        _convergeController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncMotionState();
    final accentColor = widget.config.accentColor ?? context.accentColor;
    final hasAction = widget.config.onAction != null;
    final activityFactor = widget.config.actionEnabled ? 1.0 : 0.7;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing32),
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
                  if (_reduceMotion)
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accentColor.withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.7],
                        ),
                      ),
                    )
                  else
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
                  if (_reduceMotion)
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                    )
                  else
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
                    padding: const EdgeInsets.all(AppTheme.spacing24),
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
                    child: _AnimatedIconCycle(
                      icons: widget.config.icons,
                      builder: (icon) => _buildGradientIcon(
                        context,
                        icon,
                        animate: !_reduceMotion,
                      ),
                    ),
                  ),

                  // Floating nodes — wrapped in RepaintBoundary to isolate
                  // repaints from the rest of the widget subtree. The
                  // AnimatedBuilder observes both _floatController (for time-
                  // based motion) and _convergeController (for the converge
                  // tap effect) so it rebuilds only this layer, not the
                  // entire empty-state tree.
                  if (!_reduceMotion)
                    RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _floatController,
                          _convergeController,
                        ]),
                        builder: (context, child) {
                          final floatTime = _floatTime;
                          final converge =
                              1 - (_convergeController.value * 0.25);
                          return Stack(
                            alignment: Alignment.center,
                            children: _floatingNodes.map((node) {
                              final oscillation = sin(
                                floatTime *
                                        2 *
                                        pi *
                                        node.speed *
                                        activityFactor +
                                    node.phaseOffset,
                              );
                              final angle =
                                  node.angle + (oscillation * node.sweep);
                              final wobblePhase =
                                  floatTime * 2 * pi * node.wobbleSpeed +
                                  node.phaseOffset;
                              final radius =
                                  node.radius *
                                  converge *
                                  (1 +
                                      sin(wobblePhase + node.angle) *
                                          node.wobble);
                              final depthScale = 0.4 + (node.radius / 140);
                              final parallax =
                                  (_tiltOffset + (_gyroOffset * 0.4)) *
                                  activityFactor;
                              final x =
                                  cos(angle) * radius +
                                  parallax.dx * depthScale;
                              final y =
                                  sin(angle) * radius +
                                  parallax.dy * depthScale;
                              final opacity =
                                  node.opacity *
                                  (widget.config.actionEnabled ? 1.0 : 0.6);

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
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing24),

            // Title with gradient keyword
            Builder(
              builder: (context) {
                final baseStyle = TextStyle(
                  color: context.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                );
                final gradient = LinearGradient(
                  colors: AccentColors.gradientFor(accentColor),
                );
                return RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: baseStyle,
                    children: [
                      if (widget.config.titlePrefix.isNotEmpty)
                        TextSpan(text: widget.config.titlePrefix),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: AnimatedGradientMask(
                          gradient: gradient,
                          animate: !_reduceMotion,
                          child: Text(
                            widget.config.titleKeyword,
                            style: baseStyle.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (widget.config.titleSuffix.isNotEmpty)
                        TextSpan(text: widget.config.titleSuffix),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: AppTheme.spacing8),

            // Cycling taglines
            SizedBox(
              height: 80,
              child: Center(
                child: AnimatedTagline(
                  taglines: widget.config.taglines,
                  textStyle: TextStyle(
                    color: context.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            if (hasAction) ...[
              const SizedBox(height: AppTheme.spacing32),

              // Action button
              _AnimatedActionButton(
                label: widget.config.actionLabel!,
                icon: widget.config.actionIcon,
                enabled: widget.config.actionEnabled,
                disabledReason: widget.config.actionDisabledReason,
                accentColor: accentColor,
                onTap: () {
                  _triggerConverge();
                  widget.config.onAction!();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Animated icon cycle that fades and slides between icons
class _AnimatedIconCycle extends StatefulWidget {
  const _AnimatedIconCycle({required this.icons, required this.builder});

  final List<IconData> icons;
  final Widget Function(IconData icon) builder;

  @override
  State<_AnimatedIconCycle> createState() => _AnimatedIconCycleState();
}

class _AnimatedIconCycleState extends State<_AnimatedIconCycle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _currentIndex = 0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimatedTagline.animationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _startCycling();
  }

  void _startCycling() {
    if (_reduceMotion) return;
    Future.delayed(AnimatedTagline.displayDuration, () {
      if (!mounted) return;
      if (_reduceMotion) return;
      _cycleToNext();
    });
  }

  Future<void> _cycleToNext() async {
    if (!mounted || _reduceMotion) return;
    await _controller.reverse();
    if (!mounted || _reduceMotion) return;

    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.icons.length;
    });

    await _controller.forward();
    if (!mounted || _reduceMotion) return;

    _startCycling();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion == _reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _controller.value = 1.0;
      _currentIndex = 0;
      return;
    }
    _controller.value = 1.0;
    _startCycling();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) {
      return widget.builder(widget.icons.first);
    }
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.builder(widget.icons[_currentIndex]),
      ),
    );
  }
}

/// Animated action button with gradient and pulse effect
class _AnimatedActionButton extends StatefulWidget {
  const _AnimatedActionButton({
    required this.label,
    this.icon,
    required this.enabled,
    this.disabledReason,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool enabled;
  final String? disabledReason;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.enabled) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AnimatedActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled && !_reduceMotion) {
        _glowController.repeat(reverse: true);
      } else {
        _glowController.stop();
        _glowController.value = 0;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion == _reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion || !widget.enabled) {
      _glowController.stop();
      _glowController.value = 0;
    } else {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = AccentColors.gradientFor(widget.accentColor);
    final gradient = LinearGradient(colors: gradientColors);

    return Tooltip(
      message: widget.disabledReason ?? '',
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final glowIntensity = widget.enabled && !_reduceMotion
                ? _glowController.value * 0.3
                : 0.0;

            return AnimatedGradientBackground(
              gradient: gradient,
              animate: widget.enabled && !_reduceMotion,
              enabled: widget.enabled,
              borderRadius: BorderRadius.circular(AppTheme.radius24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: widget.enabled
                      ? null
                      : context.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppTheme.radius24),
                  boxShadow: widget.enabled
                      ? [
                          BoxShadow(
                            color: widget.accentColor.withValues(
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
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        color: widget.enabled
                            ? Colors.white
                            : context.textTertiary,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacing8),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.enabled
                            ? Colors.white
                            : context.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
