import 'dart:math';

import 'package:flutter/material.dart';

/// Brand gradient colors from web/landing.css
const _brandGradientColors = [
  Color(0xFFE91E8C), // Pink/Magenta
  Color(0xFF8B5CF6), // Purple
  Color(0xFF4F6AF6), // Blue
];

/// Characters for split-flap display (standard Vestaboard charset)
const _splitFlapChars =
    ' ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$()+-&=;:\'"%,./?°';

/// A premium split-flap (Vestaboard-style) animated text widget.
/// Each letter flips through characters with realistic 3D mechanics.
class SplitFlapText extends StatefulWidget {
  const SplitFlapText({
    super.key,
    required this.text,
    this.style,
    this.useGradient = false,
    this.letterWidth = 24,
    this.letterHeight = 32,
    this.flipDuration = const Duration(milliseconds: 80),
    this.staggerDelay = const Duration(milliseconds: 120),
  });

  final String text;
  final TextStyle? style;
  final bool useGradient;
  final double letterWidth;
  final double letterHeight;
  final Duration flipDuration;
  final Duration staggerDelay;

  @override
  State<SplitFlapText> createState() => _SplitFlapTextState();
}

class _SplitFlapTextState extends State<SplitFlapText>
    with TickerProviderStateMixin {
  late List<_SplitFlapLetterController> _controllers;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _controllers = [];

    for (var i = 0; i < widget.text.length; i++) {
      final targetChar = widget.text[i].toUpperCase();
      final targetIndex = _splitFlapChars.indexOf(targetChar);
      final finalIndex = targetIndex >= 0 ? targetIndex : 0;

      // Random number of flips before landing (8-16 flips)
      final flipCount = 8 + _random.nextInt(9);

      final controller = _SplitFlapLetterController(
        vsync: this,
        flipDuration: widget.flipDuration,
        totalFlips: flipCount,
        targetIndex: finalIndex,
      );

      // Stagger from right to left (last letter starts first)
      final reverseIndex = widget.text.length - 1 - i;
      final delay = Duration(
        milliseconds: reverseIndex * widget.staggerDelay.inMilliseconds,
      );

      Future.delayed(delay, () {
        if (mounted) controller.start();
      });

      _controllers.add(controller);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.text.length, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: _SplitFlapLetter(
            controller: _controllers[index],
            width: widget.letterWidth,
            height: widget.letterHeight,
            style: widget.style,
            useGradient: widget.useGradient,
            gradientPosition: index / (widget.text.length - 1).clamp(1, 999),
          ),
        );
      }),
    );
  }
}

/// Controller for a single split-flap letter
class _SplitFlapLetterController {
  _SplitFlapLetterController({
    required TickerProvider vsync,
    required this.flipDuration,
    required this.totalFlips,
    required this.targetIndex,
  }) {
    _flipController = AnimationController(duration: flipDuration, vsync: vsync);

    _flipAnimation = Tween<double>(
      begin: 0,
      end: pi,
    ).animate(CurvedAnimation(parent: _flipController, curve: Curves.easeIn));
  }

  final Duration flipDuration;
  final int totalFlips;
  final int targetIndex;

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  int _currentFlip = 0;
  int _currentCharIndex = 0;
  int _nextCharIndex = 0;
  bool _isFlipping = false;
  bool _isComplete = false;

  Animation<double> get flipAnimation => _flipAnimation;
  bool get isFlipping => _isFlipping;
  bool get isComplete => _isComplete;
  String get currentChar => _splitFlapChars[_currentCharIndex];
  String get nextChar => _splitFlapChars[_nextCharIndex];

  final _listeners = <VoidCallback>[];

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
    _flipController.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
    _flipController.removeListener(listener);
  }

  void start() {
    _doFlip();
  }

  void _doFlip() {
    if (_currentFlip >= totalFlips) {
      _isComplete = true;
      _currentCharIndex = targetIndex;
      for (final l in _listeners) {
        l();
      }
      return;
    }

    _isFlipping = true;

    // Calculate next character - accelerate towards target near the end
    if (_currentFlip >= totalFlips - 3) {
      // Last 3 flips - move towards target
      final remaining = totalFlips - _currentFlip;
      final step = ((targetIndex - _currentCharIndex) / remaining).round();
      _nextCharIndex = (_currentCharIndex + step).clamp(
        0,
        _splitFlapChars.length - 1,
      );
    } else {
      // Random character
      _nextCharIndex = Random().nextInt(_splitFlapChars.length);
    }

    _flipController.forward(from: 0).then((_) {
      _currentCharIndex = _nextCharIndex;
      _currentFlip++;
      _isFlipping = false;

      // Small pause between flips for realism
      Future.delayed(const Duration(milliseconds: 20), () {
        _doFlip();
      });
    });
  }

  void dispose() {
    _flipController.dispose();
  }
}

/// A single split-flap letter with 3D flip animation
class _SplitFlapLetter extends StatefulWidget {
  const _SplitFlapLetter({
    required this.controller,
    required this.width,
    required this.height,
    this.style,
    this.useGradient = false,
    this.gradientPosition = 0,
  });

  final _SplitFlapLetterController controller;
  final double width;
  final double height;
  final TextStyle? style;
  final bool useGradient;
  final double gradientPosition;

  @override
  State<_SplitFlapLetter> createState() => _SplitFlapLetterState();
}

class _SplitFlapLetterState extends State<_SplitFlapLetter> {
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
    final flipValue = widget.controller.flipAnimation.value;
    final isTopHalfFlipping = flipValue < pi / 2;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          // Bottom half (static, shows next character)
          Positioned(
            top: widget.height / 2,
            left: 0,
            right: 0,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 0.5,
                child: _buildCharacter(
                  widget.controller.isFlipping
                      ? widget.controller.nextChar
                      : widget.controller.currentChar,
                ),
              ),
            ),
          ),

          // Top half (static, shows current character)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: 0.5,
                child: _buildCharacter(widget.controller.currentChar),
              ),
            ),
          ),

          // Flipping panel
          if (widget.controller.isFlipping)
            Positioned(
              top: isTopHalfFlipping ? 0 : widget.height / 2,
              left: 0,
              right: 0,
              child: Transform(
                alignment: isTopHalfFlipping
                    ? Alignment.bottomCenter
                    : Alignment.topCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateX(isTopHalfFlipping ? -flipValue : pi - flipValue),
                child: ClipRect(
                  child: Align(
                    alignment: isTopHalfFlipping
                        ? Alignment.bottomCenter
                        : Alignment.topCenter,
                    heightFactor: 0.5,
                    child: _buildCharacter(
                      isTopHalfFlipping
                          ? widget.controller.currentChar
                          : widget.controller.nextChar,
                    ),
                  ),
                ),
              ),
            ),

          // Center divider line
          Positioned(
            top: widget.height / 2 - 0.5,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacter(String char) {
    final baseStyle = (widget.style ?? const TextStyle()).copyWith(
      fontSize: widget.height * 0.75,
      fontWeight: FontWeight.w700,
      height: 1.0,
    );

    Widget text = SizedBox(
      height: widget.height,
      child: Center(
        child: Text(
          char,
          style: baseStyle.copyWith(
            color: widget.useGradient ? Colors.white : null,
          ),
        ),
      ),
    );

    if (widget.useGradient) {
      text = ShaderMask(
        shaderCallback: (bounds) {
          return LinearGradient(
            colors: _brandGradientColors,
            stops: const [0.0, 0.5, 1.0],
          ).createShader(
            Rect.fromLTWH(
              -bounds.width * widget.gradientPosition * 5,
              0,
              bounds.width * 6,
              bounds.height,
            ),
          );
        },
        blendMode: BlendMode.srcIn,
        child: text,
      );
    }

    return text;
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
        // "mesh" - animated split-flap with gradient
        SplitFlapText(
          text: 'mesh',
          style: baseStyle,
          useGradient: true,
          letterWidth: fontSize * 0.7,
          letterHeight: fontSize * 1.1,
          flipDuration: const Duration(milliseconds: 60),
          staggerDelay: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}
