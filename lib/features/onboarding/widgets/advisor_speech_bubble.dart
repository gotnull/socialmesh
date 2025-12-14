import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// A sci-fi styled speech bubble for the mesh brain advisor.
/// Features typing animation, glowing edges, and holographic effects.
class AdvisorSpeechBubble extends StatefulWidget {
  /// The text to display
  final String text;

  /// Accent color for the bubble
  final Color accentColor;

  /// Whether to animate typing effect
  final bool typewriterEffect;

  /// Typing speed in milliseconds per character
  final int typingSpeed;

  /// Callback when typing is complete
  final VoidCallback? onTypingComplete;

  /// Whether the bubble is visible
  final bool visible;

  /// Optional subtitle/hint text
  final String? subtitle;

  const AdvisorSpeechBubble({
    super.key,
    required this.text,
    this.accentColor = AppTheme.primaryMagenta,
    this.typewriterEffect = true,
    this.typingSpeed = 30,
    this.onTypingComplete,
    this.visible = true,
    this.subtitle,
  });

  @override
  State<AdvisorSpeechBubble> createState() => _AdvisorSpeechBubbleState();
}

class _AdvisorSpeechBubbleState extends State<AdvisorSpeechBubble>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _entryController;
  late AnimationController _scanlineController;

  late Animation<double> _glow;
  late Animation<double> _entry;
  late Animation<double> _scanline;

  String _displayedText = '';
  Timer? _typingTimer;
  int _currentCharIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    if (widget.visible) {
      _startEntry();
    }
  }

  void _initializeAnimations() {
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _entryController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scanlineController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _glow = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _entry = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );

    _scanline = Tween<double>(begin: 0, end: 1).animate(_scanlineController);
  }

  void _startEntry() {
    _entryController.forward();
    if (widget.typewriterEffect) {
      _startTyping();
    } else {
      _displayedText = widget.text;
    }
  }

  void _startTyping() {
    _currentCharIndex = 0;
    _displayedText = '';
    _typingTimer?.cancel();

    _typingTimer = Timer.periodic(Duration(milliseconds: widget.typingSpeed), (
      timer,
    ) {
      if (_currentCharIndex < widget.text.length) {
        setState(() {
          _displayedText = widget.text.substring(0, _currentCharIndex + 1);
          _currentCharIndex++;
        });
      } else {
        timer.cancel();
        widget.onTypingComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(AdvisorSpeechBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Restart typing if text changed or typewriter effect was just enabled
    if (oldWidget.text != widget.text ||
        (!oldWidget.typewriterEffect && widget.typewriterEffect)) {
      if (widget.typewriterEffect) {
        _startTyping();
      } else {
        setState(() => _displayedText = widget.text);
      }
    }

    if (!oldWidget.visible && widget.visible) {
      _startEntry();
    } else if (oldWidget.visible && !widget.visible) {
      _entryController.reverse();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _entryController.dispose();
    _scanlineController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _glowController,
        _entryController,
        _scanlineController,
      ]),
      builder: (context, child) {
        if (_entry.value == 0) return const SizedBox.shrink();

        return Transform.scale(
          scale: 0.8 + _entry.value * 0.2,
          child: Opacity(opacity: _entry.value, child: _buildBubble()),
        );
      },
    );
  }

  Widget _buildBubble() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        children: [
          // Outer glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(
                      alpha: _glow.value * 0.3,
                    ),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // Main bubble
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.darkCard.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.accentColor.withValues(alpha: _glow.value),
                  width: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  // Scanline effect
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ScanlinePainter(
                        progress: _scanline.value,
                        color: widget.accentColor.withValues(alpha: 0.1),
                      ),
                    ),
                  ),

                  // Corner decorations
                  _buildCornerDecoration(Alignment.topLeft),
                  _buildCornerDecoration(Alignment.topRight),
                  _buildCornerDecoration(Alignment.bottomLeft),
                  _buildCornerDecoration(Alignment.bottomRight),

                  // Content - Fixed height with scrollable text
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header indicator
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.accentColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.accentColor,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'MESH ADVISOR',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: widget.accentColor,
                                  letterSpacing: 2,
                                  fontFamily: AppTheme.fontFamily,
                                ),
                              ),
                              const Spacer(),
                              // Typing indicator
                              if (_currentCharIndex < widget.text.length &&
                                  widget.typewriterEffect)
                                _buildTypingIndicator(),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Main text with cursor - scrollable
                          Expanded(
                            child: ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white,
                                    Colors.white,
                                    Colors.white,
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                  stops: const [0.0, 0.7, 0.9, 1.0],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.dstIn,
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                      height: 1.5,
                                      fontFamily: AppTheme.fontFamily,
                                    ),
                                    children: [
                                      TextSpan(text: _displayedText),
                                      if (_currentCharIndex <
                                              widget.text.length &&
                                          widget.typewriterEffect)
                                        TextSpan(
                                          text: '▌',
                                          style: TextStyle(
                                            color: widget.accentColor
                                                .withValues(alpha: _glow.value),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Subtitle
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textTertiary,
                                fontStyle: FontStyle.italic,
                                fontFamily: AppTheme.fontFamily,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Connector tail pointing up
          Positioned(
            top: -8,
            left: 0,
            right: 0,
            child: Center(
              child: CustomPaint(
                size: const Size(20, 10),
                painter: _BubbleTailPainter(
                  color: AppTheme.darkCard.withValues(alpha: 0.9),
                  borderColor: widget.accentColor.withValues(
                    alpha: _glow.value,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerDecoration(Alignment alignment) {
    return Positioned(
      left: alignment.x < 0 ? 4 : null,
      right: alignment.x > 0 ? 4 : null,
      top: alignment.y < 0 ? 4 : null,
      bottom: alignment.y > 0 ? 4 : null,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          border: Border(
            left: alignment.x < 0
                ? BorderSide(
                    color: widget.accentColor.withValues(alpha: 0.5),
                    width: 2,
                  )
                : BorderSide.none,
            right: alignment.x > 0
                ? BorderSide(
                    color: widget.accentColor.withValues(alpha: 0.5),
                    width: 2,
                  )
                : BorderSide.none,
            top: alignment.y < 0
                ? BorderSide(
                    color: widget.accentColor.withValues(alpha: 0.5),
                    width: 2,
                  )
                : BorderSide.none,
            bottom: alignment.y > 0
                ? BorderSide(
                    color: widget.accentColor.withValues(alpha: 0.5),
                    width: 2,
                  )
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      children: List.generate(3, (i) {
        final delay = i * 0.2;
        final opacity = (math.sin((_glow.value + delay) * math.pi * 2) + 1) / 2;
        return Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.accentColor.withValues(alpha: opacity),
          ),
        );
      }),
    );
  }
}

/// Custom painter for scanline effect
class _ScanlinePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScanlinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final y = progress * size.height;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, color, color, Colors.transparent],
        stops: const [0.0, 0.45, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, y - 20, size.width, 40));

    canvas.drawRect(Rect.fromLTWH(0, y - 20, size.width, 40), paint);
  }

  @override
  bool shouldRepaint(_ScanlinePainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// Custom painter for bubble tail
class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _BubbleTailPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2 - 10, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width / 2 + 10, size.height)
      ..close();

    // Fill
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    // Border
    canvas.drawPath(
      Path()
        ..moveTo(size.width / 2 - 10, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width / 2 + 10, size.height),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_BubbleTailPainter oldDelegate) =>
      color != oldDelegate.color || borderColor != oldDelegate.borderColor;
}
