import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socialmesh/core/theme.dart';

/// Enum for different secret gesture patterns
enum SecretGesturePattern {
  /// Tap 7 times quickly (like Android developer options)
  sevenTaps,

  /// Triforce pattern: tap top, bottom-left, bottom-right corners
  triforce,

  /// Konami-style: swipe up, up, down, down, left, right, left, right
  konami,

  /// Hold for 3 seconds then tap 3 times quickly
  holdAndTap,

  /// Draw a spiral pattern (circular motion)
  spiral,
}

/// A widget that detects secret gesture patterns to unlock hidden features.
/// Think Zelda puzzles or the Android developer options unlock!
class SecretGestureDetector extends StatefulWidget {
  /// The child widget to wrap
  final Widget child;

  /// The pattern to detect
  final SecretGesturePattern pattern;

  /// Callback when the secret pattern is completed
  final VoidCallback onSecretUnlocked;

  /// Optional callback for progress (0.0 to 1.0)
  final ValueChanged<double>? onProgress;

  /// Time window for completing the pattern (default 3 seconds for taps)
  final Duration timeWindow;

  /// Whether to show visual feedback during the gesture
  final bool showFeedback;

  /// Whether to play haptic feedback
  final bool enableHaptics;

  const SecretGestureDetector({
    super.key,
    required this.child,
    required this.onSecretUnlocked,
    this.pattern = SecretGesturePattern.sevenTaps,
    this.onProgress,
    this.timeWindow = const Duration(seconds: 3),
    this.showFeedback = false,
    this.enableHaptics = true,
  });

  @override
  State<SecretGestureDetector> createState() => _SecretGestureDetectorState();
}

class _SecretGestureDetectorState extends State<SecretGestureDetector>
    with SingleTickerProviderStateMixin {
  // Tap counter state
  int _tapCount = 0;
  Timer? _tapResetTimer;

  // Hold and tap state
  bool _isHolding = false;
  Timer? _holdTimer;
  int _postHoldTaps = 0;

  // Konami state
  final List<_SwipeDirection> _konamiSequence = [];
  static const _konamiCode = [
    _SwipeDirection.up,
    _SwipeDirection.up,
    _SwipeDirection.down,
    _SwipeDirection.down,
    _SwipeDirection.left,
    _SwipeDirection.right,
    _SwipeDirection.left,
    _SwipeDirection.right,
  ];

  // Triforce state
  final List<_TapZone> _triforceSequence = [];
  static const _triforceCode = [
    _TapZone.top,
    _TapZone.bottomLeft,
    _TapZone.bottomRight,
  ];

  // Spiral state
  final List<Offset> _spiralPoints = [];
  double _lastAngle = 0;
  double _totalRotation = 0;

  // Animation
  late AnimationController _pulseController;
  double _currentProgress = 0.0;

  // Visual feedback state
  final List<_RippleEffect> _ripples = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    _holdTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _resetState() {
    _tapCount = 0;
    _isHolding = false;
    _postHoldTaps = 0;
    _konamiSequence.clear();
    _triforceSequence.clear();
    _spiralPoints.clear();
    _totalRotation = 0;
    _currentProgress = 0.0;
    widget.onProgress?.call(0.0);
  }

  void _updateProgress(double progress) {
    setState(() => _currentProgress = progress.clamp(0.0, 1.0));
    widget.onProgress?.call(_currentProgress);
  }

  void _triggerSuccess() {
    if (widget.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
    _resetState();
    widget.onSecretUnlocked();
  }

  void _triggerPartialFeedback() {
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    if (widget.showFeedback) {
      _pulseController.forward(from: 0);
    }
  }

  // ============ SEVEN TAPS PATTERN ============
  void _handleSevenTaps(TapDownDetails details) {
    _tapResetTimer?.cancel();
    _tapCount++;
    _updateProgress(_tapCount / 7.0);
    _triggerPartialFeedback();

    // Add ripple effect
    if (widget.showFeedback) {
      setState(() {
        _ripples.add(_RippleEffect(position: details.localPosition));
      });
    }

    if (_tapCount >= 7) {
      _triggerSuccess();
    } else {
      _tapResetTimer = Timer(widget.timeWindow, _resetState);
    }
  }

  // ============ HOLD AND TAP PATTERN ============
  void _handleHoldStart(LongPressStartDetails details) {
    _isHolding = true;
    _postHoldTaps = 0;
    _updateProgress(0.1);

    _holdTimer = Timer(const Duration(seconds: 3), () {
      if (_isHolding) {
        _updateProgress(0.5);
        _triggerPartialFeedback();
        if (widget.enableHaptics) {
          HapticFeedback.mediumImpact();
        }
      }
    });
  }

  void _handleHoldEnd(LongPressEndDetails details) {
    _holdTimer?.cancel();
    if (_currentProgress >= 0.5) {
      // Hold was successful, now listen for 3 taps
      _tapResetTimer = Timer(widget.timeWindow, _resetState);
    } else {
      _resetState();
    }
    _isHolding = false;
  }

  void _handlePostHoldTap(TapDownDetails details) {
    if (_currentProgress >= 0.5 && !_isHolding) {
      _postHoldTaps++;
      _updateProgress(0.5 + (_postHoldTaps / 3.0) * 0.5);
      _triggerPartialFeedback();

      if (_postHoldTaps >= 3) {
        _triggerSuccess();
      }
    }
  }

  // ============ KONAMI PATTERN ============
  void _handleKonamiSwipe(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    _SwipeDirection? direction;

    if (velocity.dy.abs() > velocity.dx.abs()) {
      direction = velocity.dy < 0 ? _SwipeDirection.up : _SwipeDirection.down;
    } else if (velocity.dx.abs() > 30) {
      direction = velocity.dx < 0
          ? _SwipeDirection.left
          : _SwipeDirection.right;
    }

    if (direction != null) {
      final expectedDirection = _konamiSequence.length < _konamiCode.length
          ? _konamiCode[_konamiSequence.length]
          : null;

      if (direction == expectedDirection) {
        _konamiSequence.add(direction);
        _updateProgress(_konamiSequence.length / _konamiCode.length);
        _triggerPartialFeedback();

        if (_konamiSequence.length >= _konamiCode.length) {
          _triggerSuccess();
        }
      } else {
        _resetState();
      }
    }
  }

  // ============ TRIFORCE PATTERN ============
  void _handleTriforce(TapDownDetails details, Size size) {
    final zone = _getTapZone(details.localPosition, size);

    final expectedZone = _triforceSequence.length < _triforceCode.length
        ? _triforceCode[_triforceSequence.length]
        : null;

    if (zone == expectedZone) {
      _triforceSequence.add(zone);
      _updateProgress(_triforceSequence.length / _triforceCode.length);
      _triggerPartialFeedback();

      // Add golden ripple for Zelda feel
      if (widget.showFeedback) {
        setState(() {
          _ripples.add(
            _RippleEffect(
              position: details.localPosition,
              color: const Color(0xFFFFD700),
            ),
          );
        });
      }

      if (_triforceSequence.length >= _triforceCode.length) {
        _triggerSuccess();
      } else {
        _tapResetTimer?.cancel();
        _tapResetTimer = Timer(widget.timeWindow, _resetState);
      }
    } else {
      _resetState();
    }
  }

  _TapZone _getTapZone(Offset position, Size size) {
    final centerX = size.width / 2;
    final thirdHeight = size.height / 3;

    if (position.dy < thirdHeight) {
      return _TapZone.top;
    } else if (position.dx < centerX) {
      return _TapZone.bottomLeft;
    } else {
      return _TapZone.bottomRight;
    }
  }

  // ============ SPIRAL PATTERN ============
  void _handleSpiralUpdate(DragUpdateDetails details) {
    _spiralPoints.add(details.localPosition);

    if (_spiralPoints.length > 10) {
      final center = _calculateCenter(_spiralPoints);
      final currentAngle = math.atan2(
        details.localPosition.dy - center.dy,
        details.localPosition.dx - center.dx,
      );

      if (_spiralPoints.length > 20) {
        var angleDiff = currentAngle - _lastAngle;
        // Handle angle wrap-around
        if (angleDiff > math.pi) angleDiff -= 2 * math.pi;
        if (angleDiff < -math.pi) angleDiff += 2 * math.pi;

        _totalRotation += angleDiff;
        _updateProgress((_totalRotation.abs() / (2 * math.pi * 2)).clamp(0, 1));

        // Two full rotations to unlock
        if (_totalRotation.abs() > 2 * math.pi * 2) {
          _triggerSuccess();
        }
      }

      _lastAngle = currentAngle;
    }
  }

  Offset _calculateCenter(List<Offset> points) {
    double sumX = 0, sumY = 0;
    for (final p in points) {
      sumX += p.dx;
      sumY += p.dy;
    }
    return Offset(sumX / points.length, sumY / points.length);
  }

  void _handleSpiralEnd(DragEndDetails details) {
    if (_currentProgress < 1.0) {
      _resetState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        Widget gestureChild = Stack(
          children: [
            widget.child,
            // Ripple effects overlay
            if (widget.showFeedback && _ripples.isNotEmpty)
              ..._ripples.map(
                (r) => _RippleWidget(
                  key: ValueKey(r.hashCode),
                  position: r.position,
                  color: r.color,
                  onComplete: () => setState(() => _ripples.remove(r)),
                ),
              ),
            // Progress indicator
            if (widget.showFeedback && _currentProgress > 0)
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: _ProgressIndicator(progress: _currentProgress),
              ),
          ],
        );

        switch (widget.pattern) {
          case SecretGesturePattern.sevenTaps:
            return GestureDetector(
              onTapDown: _handleSevenTaps,
              child: gestureChild,
            );

          case SecretGesturePattern.holdAndTap:
            return GestureDetector(
              onLongPressStart: _handleHoldStart,
              onLongPressEnd: _handleHoldEnd,
              onTapDown: _handlePostHoldTap,
              child: gestureChild,
            );

          case SecretGesturePattern.konami:
            return GestureDetector(
              onPanEnd: _handleKonamiSwipe,
              child: gestureChild,
            );

          case SecretGesturePattern.triforce:
            return GestureDetector(
              onTapDown: (d) => _handleTriforce(d, size),
              child: gestureChild,
            );

          case SecretGesturePattern.spiral:
            return GestureDetector(
              onPanUpdate: _handleSpiralUpdate,
              onPanEnd: _handleSpiralEnd,
              child: gestureChild,
            );
        }
      },
    );
  }
}

// ============ HELPER CLASSES ============

enum _SwipeDirection { up, down, left, right }

enum _TapZone { top, bottomLeft, bottomRight }

class _RippleEffect {
  final Offset position;
  final Color color;

  _RippleEffect({required this.position, this.color = SemanticColors.onBrand});
}

class _RippleWidget extends StatefulWidget {
  final Offset position;
  final Color color;
  final VoidCallback onComplete;

  const _RippleWidget({
    super.key,
    required this.position,
    required this.color,
    required this.onComplete,
  });

  @override
  State<_RippleWidget> createState() => _RippleWidgetState();
}

class _RippleWidgetState extends State<_RippleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = _controller.value;
        return Positioned(
          left: widget.position.dx - 30 * value,
          top: widget.position.dy - 30 * value,
          child: Container(
            width: 60 * value,
            height: 60 * value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.color.withValues(alpha: 1.0 - value),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  final double progress;

  const _ProgressIndicator({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 3,
        decoration: BoxDecoration(
          color: SemanticColors.glow(0.2),
          borderRadius: BorderRadius.circular(2),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B4A), Color(0xFFE91E8C)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
