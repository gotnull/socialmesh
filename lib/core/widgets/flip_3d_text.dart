import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A 3D flip/rotate text widget that animates number changes with perspective
/// Similar to a flip clock or rotating billboard effect
class Flip3DText extends StatefulWidget {
  const Flip3DText({
    super.key,
    required this.value,
    this.suffix = '%',
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutBack,
    this.direction = Flip3DDirection.vertical,
    this.perspective = 0.003,
  });

  /// The numeric value to display
  final double value;

  /// Suffix to append (e.g., '%', 'dB', etc.)
  final String suffix;

  /// Text style for the value
  final TextStyle? style;

  /// Animation duration
  final Duration duration;

  /// Animation curve
  final Curve curve;

  /// Flip direction (vertical or horizontal)
  final Flip3DDirection direction;

  /// Perspective depth (higher = more dramatic 3D effect)
  final double perspective;

  @override
  State<Flip3DText> createState() => _Flip3DTextState();
}

enum Flip3DDirection { vertical, horizontal }

class _Flip3DTextState extends State<Flip3DText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;

  double _previousValue = 0;
  double _currentValue = 0;
  bool _showingNew = false;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
    _previousValue = widget.value;

    _controller = AnimationController(vsync: this, duration: widget.duration);

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: math.pi,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    _opacityAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.addListener(() {
      if (_controller.value >= 0.5 && !_showingNew) {
        setState(() => _showingNew = true);
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _previousValue = _currentValue;
        _controller.reset();
        _showingNew = false;
      }
    });
  }

  @override
  void didUpdateWidget(Flip3DText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = _currentValue;
      _currentValue = widget.value;
      _showingNew = false;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = Theme.of(context).textTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
    final effectiveStyle = widget.style ?? defaultStyle;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final rotation = _rotationAnimation.value;
        final displayValue = _showingNew ? _currentValue : _previousValue;

        // Calculate transforms based on direction
        Matrix4 transform = Matrix4.identity()
          ..setEntry(3, 2, widget.perspective);

        if (widget.direction == Flip3DDirection.vertical) {
          transform.rotateX(_showingNew ? rotation - math.pi : rotation);
        } else {
          transform.rotateY(_showingNew ? rotation - math.pi : rotation);
        }

        return Transform(
          transform: transform,
          alignment: Alignment.center,
          child: Opacity(
            opacity: _showingNew ? 1.0 : _opacityAnimation.value,
            child: Text(
              '${displayValue.toStringAsFixed(0)}${widget.suffix}',
              style: effectiveStyle,
            ),
          ),
        );
      },
    );
  }
}

/// A more dramatic 3D percentage display with multiple layers
class Flip3DPercentage extends StatefulWidget {
  const Flip3DPercentage({
    super.key,
    required this.value,
    this.label,
    this.color,
    this.size = Flip3DSize.medium,
    this.showGlow = true,
  });

  final double value;
  final String? label;
  final Color? color;
  final Flip3DSize size;
  final bool showGlow;

  @override
  State<Flip3DPercentage> createState() => _Flip3DPercentageState();
}

enum Flip3DSize { small, medium, large }

class _Flip3DPercentageState extends State<Flip3DPercentage>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _glowController;
  late Animation<double> _flipAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  double _previousValue = 0;
  double _displayValue = 0;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value;
    _previousValue = widget.value;

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeOutBack),
    );

    _scaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.1), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 30),
        ]).animate(
          CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
        );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _flipController.addListener(_updateDisplayValue);
  }

  void _updateDisplayValue() {
    final progress = _flipAnimation.value;
    setState(() {
      _displayValue =
          _previousValue + (_displayValue - _previousValue) * progress;
    });
  }

  @override
  void didUpdateWidget(Flip3DPercentage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = _displayValue;
      _displayValue = widget.value;
      _flipController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  double get _fontSize {
    return switch (widget.size) {
      Flip3DSize.small => 32,
      Flip3DSize.medium => 48,
      Flip3DSize.large => 72,
    };
  }

  double get _suffixSize {
    return switch (widget.size) {
      Flip3DSize.small => 16,
      Flip3DSize.medium => 24,
      Flip3DSize.large => 36,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = widget.color ?? theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: Listenable.merge([_flipController, _glowController]),
      builder: (context, child) {
        final rotation = _flipAnimation.value * math.pi * 2;
        final scaleValue = _scaleAnimation.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main percentage display with 3D effect
            Transform.scale(
              scale: scaleValue,
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateX(math.sin(rotation) * 0.1)
                  ..rotateY(math.cos(rotation) * 0.05),
                alignment: Alignment.center,
                child: Container(
                  decoration: widget.showGlow
                      ? BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: effectiveColor.withValues(
                                alpha: _glowAnimation.value * 0.5,
                              ),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        )
                      : null,
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        effectiveColor,
                        effectiveColor.withValues(alpha: 0.7),
                        Colors.white.withValues(alpha: 0.9),
                        effectiveColor.withValues(alpha: 0.7),
                        effectiveColor,
                      ],
                      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                    ).createShader(bounds),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        // Main number
                        Text(
                          _displayValue.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: _fontSize,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1,
                            shadows: [
                              Shadow(
                                color: effectiveColor.withValues(alpha: 0.5),
                                blurRadius: 20,
                              ),
                              const Shadow(
                                color: Colors.black26,
                                offset: Offset(2, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        // Percent symbol
                        Text(
                          '%',
                          style: TextStyle(
                            fontSize: _suffixSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Label
            if (widget.label != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.label!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Stacked 3D digits that flip individually (like an odometer)
class Flip3DOdometer extends StatelessWidget {
  const Flip3DOdometer({
    super.key,
    required this.value,
    this.digits = 3,
    this.suffix = '%',
    this.style,
    this.digitSpacing = 2,
  });

  final double value;
  final int digits;
  final String suffix;
  final TextStyle? style;
  final double digitSpacing;

  @override
  Widget build(BuildContext context) {
    final intValue = value.round().clamp(0, math.pow(10, digits).toInt() - 1);
    final valueStr = intValue.toString().padLeft(digits, '0');

    final defaultStyle = Theme.of(context).textTheme.displayMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: Colors.white,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...valueStr
            .split('')
            .map(
              (digit) => Padding(
                padding: EdgeInsets.symmetric(horizontal: digitSpacing),
                child: _FlipDigit(
                  digit: int.parse(digit),
                  style: style ?? defaultStyle,
                ),
              ),
            ),
        Text(
          suffix,
          style: (style ?? defaultStyle)?.copyWith(
            fontSize: ((style ?? defaultStyle)?.fontSize ?? 24) * 0.6,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _FlipDigit extends StatefulWidget {
  const _FlipDigit({required this.digit, this.style});

  final int digit;
  final TextStyle? style;

  @override
  State<_FlipDigit> createState() => _FlipDigitState();
}

class _FlipDigitState extends State<_FlipDigit>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _currentDigit = 0;
  int _previousDigit = 0;

  @override
  void initState() {
    super.initState();
    _currentDigit = widget.digit;
    _previousDigit = widget.digit;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void didUpdateWidget(_FlipDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.digit != widget.digit) {
      _previousDigit = _currentDigit;
      _currentDigit = widget.digit;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = _animation.value;
        final displayDigit = progress < 0.5 ? _previousDigit : _currentDigit;
        final rotation = progress < 0.5
            ? progress * math.pi
            : (progress - 0.5) * math.pi + math.pi;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.003)
            ..rotateX(rotation),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(displayDigit.toString(), style: widget.style),
          ),
        );
      },
    );
  }
}

/// Minimalistic 3D percentage display - clean and subtle
/// No heavy gradients or glow effects, just smooth 3D tilt animation
class Flip3DPercentageMinimal extends StatefulWidget {
  const Flip3DPercentageMinimal({
    super.key,
    required this.value,
    this.label,
    this.color,
    this.size = Flip3DSize.medium,
  });

  final double value;
  final String? label;
  final Color? color;
  final Flip3DSize size;

  @override
  State<Flip3DPercentageMinimal> createState() =>
      _Flip3DPercentageMinimalState();
}

class _Flip3DPercentageMinimalState extends State<Flip3DPercentageMinimal>
    with SingleTickerProviderStateMixin {
  late AnimationController _tiltController;
  late Animation<double> _tiltAnimation;
  late Animation<double> _valueAnimation;

  double _previousValue = 0;
  double _displayValue = 0;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value;
    _previousValue = widget.value;

    _tiltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _tiltAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0, end: 0.08), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 0.08, end: 0), weight: 50),
        ]).animate(
          CurvedAnimation(parent: _tiltController, curve: Curves.easeInOut),
        );

    _valueAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _tiltController, curve: Curves.easeOutCubic),
    );

    _tiltController.addListener(_updateDisplayValue);
  }

  void _updateDisplayValue() {
    final progress = _valueAnimation.value;
    setState(() {
      _displayValue =
          _previousValue + (widget.value - _previousValue) * progress;
    });
  }

  @override
  void didUpdateWidget(Flip3DPercentageMinimal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.value - widget.value).abs() > 0.5) {
      _previousValue = _displayValue;
      _tiltController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _tiltController.dispose();
    super.dispose();
  }

  double get _fontSize {
    return switch (widget.size) {
      Flip3DSize.small => 24,
      Flip3DSize.medium => 32,
      Flip3DSize.large => 48,
    };
  }

  double get _suffixSize {
    return switch (widget.size) {
      Flip3DSize.small => 14,
      Flip3DSize.medium => 18,
      Flip3DSize.large => 28,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = widget.color ?? theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _tiltController,
      builder: (context, child) {
        final tilt = _tiltAnimation.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main percentage display with subtle 3D tilt
            Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(tilt),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Main number
                  Text(
                    _displayValue.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: _fontSize,
                      fontWeight: FontWeight.w700,
                      color: effectiveColor,
                      height: 1,
                      letterSpacing: -1,
                    ),
                  ),
                  // Percent symbol
                  Text(
                    '%',
                    style: TextStyle(
                      fontSize: _suffixSize,
                      fontWeight: FontWeight.w500,
                      color: effectiveColor.withValues(alpha: 0.7),
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),

            // Label
            if (widget.label != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.label!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
