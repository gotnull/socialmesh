import 'dart:math';

import 'package:flutter/material.dart';

/// Brand gradient colors from web/landing.css
const _brandGradientColors = [
  Color(0xFFE91E8C), // Pink/Magenta
  Color(0xFF8B5CF6), // Purple
  Color(0xFF4F6AF6), // Blue
];

/// Characters for split-flap display cycling - includes lowercase
const _flipCharsUpper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%&';
const _flipCharsLower = 'abcdefghijklmnopqrstuvwxyz0123456789!@#%&';

/// Slot machine / Pokie style split-flap text with bouncy physics.
///
/// Features:
/// - Realistic variable-speed spinning that slows down
/// - Bouncy overshoot when landing on final character
/// - Blur effect during fast spins
/// - Randomized timing per letter for organic feel
/// - Staggered start from right-to-left like a real machine
class SplitFlapText extends StatefulWidget {
  const SplitFlapText({
    super.key,
    required this.text,
    this.style,
    this.useGradient = false,
    this.spinDuration = const Duration(milliseconds: 1800),
    this.staggerDelay = const Duration(milliseconds: 180),
  });

  final String text;
  final TextStyle? style;
  final bool useGradient;
  final Duration spinDuration;
  final Duration staggerDelay;

  @override
  State<SplitFlapText> createState() => _SplitFlapTextState();
}

class _SplitFlapTextState extends State<SplitFlapText>
    with TickerProviderStateMixin {
  late List<_LetterAnimationController> _letterControllers;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _letterControllers = List.generate(
      widget.text.length,
      (i) => _LetterAnimationController(
        targetChar: widget.text[i],
        vsync: this,
        random: _random,
      ),
    );
    _startAnimation();
  }

  @override
  void dispose() {
    for (final controller in _letterControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startAnimation() {
    for (var i = 0; i < widget.text.length; i++) {
      // Stagger from right to left with randomized delays
      final reverseIndex = widget.text.length - 1 - i;
      final baseDelay = reverseIndex * widget.staggerDelay.inMilliseconds;
      // Add ±50ms randomness for organic feel
      final jitter = _random.nextInt(100) - 50;
      final delay = Duration(milliseconds: baseDelay + jitter);

      // Vary spin duration per letter ±300ms
      final durationJitter = _random.nextInt(600) - 300;
      final spinDuration = Duration(
        milliseconds: widget.spinDuration.inMilliseconds + durationJitter,
      );

      Future.delayed(delay, () {
        if (mounted) {
          _letterControllers[i].startSpin(spinDuration);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.text.length, (index) {
        return _SlotLetter(
          controller: _letterControllers[index],
          style: widget.style,
          useGradient: widget.useGradient,
          gradientPosition: index / (widget.text.length - 1).clamp(1, 999),
        );
      }),
    );
  }
}

/// Controls the animation state for a single letter slot
class _LetterAnimationController {
  _LetterAnimationController({
    required this.targetChar,
    required TickerProvider vsync,
    required this.random,
  }) : _vsync = vsync {
    _isUpperCase =
        targetChar == targetChar.toUpperCase() &&
        targetChar != targetChar.toLowerCase();
    _flipChars = _isUpperCase ? _flipCharsUpper : _flipCharsLower;
  }

  final String targetChar;
  final TickerProvider _vsync;
  final Random random;
  late final bool _isUpperCase;
  late final String _flipChars;

  AnimationController? _spinController;
  AnimationController? _bounceController;

  String currentChar = ' ';
  double blurAmount = 0;
  double bounceOffset = 0;
  double rotationAngle = 0;

  final _listeners = <VoidCallback>[];

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  void startSpin(Duration duration) {
    _spinController = AnimationController(duration: duration, vsync: _vsync);

    // Use a custom curve that spins fast then decelerates
    final spinCurve = CurvedAnimation(
      parent: _spinController!,
      curve: const _SlotMachineCurve(),
    );

    // Calculate how many character changes based on duration
    final totalFlips = 15 + random.nextInt(10); // 15-25 flips
    var lastFlipIndex = -1;

    _spinController!.addListener(() {
      final progress = spinCurve.value;

      // Determine current flip index (which character we're showing)
      final flipIndex = (progress * totalFlips).floor();

      if (flipIndex != lastFlipIndex && flipIndex < totalFlips) {
        lastFlipIndex = flipIndex;

        // Pick random character, but ensure last few approach target
        if (flipIndex >= totalFlips - 3) {
          // Last 3 flips: 50% chance of showing target
          currentChar = random.nextBool()
              ? targetChar
              : _flipChars[random.nextInt(_flipChars.length)];
        } else {
          currentChar = _flipChars[random.nextInt(_flipChars.length)];
        }

        // Blur based on spin speed (derivative of progress)
        final speed = 1.0 - progress; // Fast at start, slow at end
        blurAmount = speed * 2.5;

        // Rotation wobble during spin
        rotationAngle = sin(progress * 20) * (1 - progress) * 0.08;

        _notifyListeners();
      }
    });

    _spinController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Set final character
        currentChar = targetChar;
        blurAmount = 0;
        rotationAngle = 0;
        _notifyListeners();

        // Start bounce animation
        _startBounce();
      }
    });

    _spinController!.forward();
  }

  void _startBounce() {
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: _vsync,
    );

    // Bouncy overshoot curve
    final bounceCurve = CurvedAnimation(
      parent: _bounceController!,
      curve: const _BouncyOvershootCurve(),
    );

    _bounceController!.addListener(() {
      // Bounce offset: overshoot down then settle
      bounceOffset = bounceCurve.value;
      _notifyListeners();
    });

    _bounceController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        bounceOffset = 0;
        _notifyListeners();
      }
    });

    _bounceController!.forward();
  }

  void dispose() {
    _spinController?.dispose();
    _bounceController?.dispose();
    _listeners.clear();
  }
}

/// Slot machine style letter with blur, bounce, and flip effects
class _SlotLetter extends StatefulWidget {
  const _SlotLetter({
    required this.controller,
    this.style,
    this.useGradient = false,
    this.gradientPosition = 0,
  });

  final _LetterAnimationController controller;
  final TextStyle? style;
  final bool useGradient;
  final double gradientPosition;

  @override
  State<_SlotLetter> createState() => _SlotLetterState();
}

class _SlotLetterState extends State<_SlotLetter> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final char = widget.controller.currentChar;
    final blur = widget.controller.blurAmount;
    final bounce = widget.controller.bounceOffset;
    final rotation = widget.controller.rotationAngle;

    Widget text = Text(
      char,
      style: widget.style?.copyWith(
        color: widget.useGradient ? Colors.white : null,
      ),
    );

    // Apply gradient shader
    if (widget.useGradient) {
      text = ShaderMask(
        shaderCallback: (bounds) {
          return LinearGradient(colors: _brandGradientColors).createShader(
            Rect.fromLTWH(
              -bounds.width * widget.gradientPosition * 4,
              0,
              bounds.width * 5,
              bounds.height,
            ),
          );
        },
        blendMode: BlendMode.srcIn,
        child: text,
      );
    }

    // Apply transformations
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setTranslationRaw(
          0.0,
          bounce * 8,
          0.0,
        ) // Bounce offset (max 8 pixels)
        ..rotateZ(rotation), // Subtle wobble during spin
      child: blur > 0.1
          ? Stack(
              children: [
                // Motion blur effect - show previous chars faded
                Opacity(
                  opacity: 0.3,
                  child: Transform.translate(
                    offset: Offset(0, -blur * 4),
                    child: text,
                  ),
                ),
                Opacity(
                  opacity: 0.15,
                  child: Transform.translate(
                    offset: Offset(0, -blur * 8),
                    child: text,
                  ),
                ),
                // Main character
                text,
              ],
            )
          : text,
    );
  }
}

/// Curve that simulates slot machine spin: fast start, gradual deceleration
class _SlotMachineCurve extends Curve {
  const _SlotMachineCurve();

  @override
  double transformInternal(double t) {
    // Deceleration curve - spins fast then slows dramatically
    // Using cubic ease-out with extra emphasis on the slowdown
    final p = 1.0 - t;
    return 1.0 - (p * p * p * p); // Quartic ease-out
  }
}

/// Bouncy overshoot curve for the landing effect
class _BouncyOvershootCurve extends Curve {
  const _BouncyOvershootCurve();

  @override
  double transformInternal(double t) {
    // Creates: 0 -> overshoot(1.3) -> undershoot(-0.1) -> settle(0)
    if (t < 0.4) {
      // Overshoot phase: 0 to 1.3
      final p = t / 0.4;
      return Curves.easeOut.transform(p) * 1.3;
    } else if (t < 0.7) {
      // Snap back past zero: 1.3 to -0.15
      final p = (t - 0.4) / 0.3;
      return 1.3 - Curves.easeInOut.transform(p) * 1.45;
    } else {
      // Settle to zero: -0.15 to 0
      final p = (t - 0.7) / 0.3;
      return -0.15 + Curves.easeOut.transform(p) * 0.15;
    }
  }
}

/// Widget that displays "Social" + animated "mesh" with gradient
class SocialmeshSplitFlapLogo extends StatelessWidget {
  const SocialmeshSplitFlapLogo({
    super.key,
    this.fontSize = 32,
    this.fontWeight = FontWeight.bold,
  });

  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: -0.5,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // "Social" - static, normal color
        Text(
          'Social',
          style: baseStyle.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
        // "mesh" - animated with gradient (LOWERCASE)
        SplitFlapText(
          text: 'mesh',
          style: baseStyle,
          useGradient: true,
          spinDuration: const Duration(milliseconds: 1600),
          staggerDelay: const Duration(milliseconds: 220),
        ),
      ],
    );
  }
}
