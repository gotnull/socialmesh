import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../help/help_content.dart';
import '../theme.dart';
import '../../features/onboarding/widgets/mesh_node_brain.dart';
import '../../providers/help_providers.dart';

// ============================================================================
// ICO HELP BUTTON - Floating button that pulses when help available
// ============================================================================

class IcoHelpButton extends ConsumerStatefulWidget {
  final String topicId;
  final Alignment alignment;
  final EdgeInsets margin;
  final bool autoTrigger;

  const IcoHelpButton({
    super.key,
    required this.topicId,
    this.alignment = Alignment.bottomRight,
    this.margin = const EdgeInsets.all(16),
    this.autoTrigger = false,
  });

  @override
  ConsumerState<IcoHelpButton> createState() => _IcoHelpButtonState();
}

class _IcoHelpButtonState extends ConsumerState<IcoHelpButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _autoTriggered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    // Only start repeating animation if enabled (disabled in tests)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final animationsEnabled = ref.read(helpAnimationsEnabledProvider);
      if (animationsEnabled) {
        _pulseController.repeat(reverse: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-trigger help on first visit
    if (widget.autoTrigger && !_autoTriggered) {
      _autoTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final helpNotifier = ref.read(helpProvider.notifier);
        if (helpNotifier.shouldAutoTrigger(widget.topicId)) {
          helpNotifier.startTour(widget.topicId);
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final helpState = ref.watch(helpProvider);
    final shouldShow = helpState.shouldShowHelp(widget.topicId);

    if (!shouldShow && !helpState.showPulsingHint) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: SafeArea(
        child: Align(
          alignment: widget.alignment,
          child: Padding(
            padding: widget.margin,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulseScale = shouldShow
                    ? 1.0 + (_pulseController.value * 0.15)
                    : 1.0;
                final glowOpacity = shouldShow
                    ? 0.3 + (_pulseController.value * 0.4)
                    : 0.0;

                return GestureDetector(
                  onTap: () =>
                      ref.read(helpProvider.notifier).startTour(widget.topicId),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryMagenta.withValues(
                            alpha: glowOpacity,
                          ),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Transform.scale(
                      scale: pulseScale,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryMagenta.withValues(alpha: 0.9),
                              AccentColors.cyan.withValues(alpha: 0.7),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryMagenta.withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.help_outline,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ICO HELP APP BAR BUTTON - App bar icon with accent ring when help mode active
// ============================================================================

/// A help button designed for app bars that shows an accent-colored ring
/// when help mode is active. Use this instead of IcoHelpButton for a cleaner
/// integration with standard app bar actions.
class IcoHelpAppBarButton extends ConsumerStatefulWidget {
  final String topicId;
  final bool autoTrigger;

  const IcoHelpAppBarButton({
    super.key,
    required this.topicId,
    this.autoTrigger = false,
  });

  @override
  ConsumerState<IcoHelpAppBarButton> createState() =>
      _IcoHelpAppBarButtonState();
}

class _IcoHelpAppBarButtonState extends ConsumerState<IcoHelpAppBarButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ringController;
  bool _autoTriggered = false;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    // Only start repeating animation if enabled (disabled in tests)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final animationsEnabled = ref.read(helpAnimationsEnabledProvider);
      if (animationsEnabled) {
        _ringController.repeat(reverse: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-trigger help on first visit
    if (widget.autoTrigger && !_autoTriggered) {
      _autoTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final helpNotifier = ref.read(helpProvider.notifier);
        if (helpNotifier.shouldAutoTrigger(widget.topicId)) {
          helpNotifier.startTour(widget.topicId);
        }
      });
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final helpState = ref.watch(helpProvider);
    final isHelpActive = helpState.activeTourId != null;

    return AnimatedBuilder(
      animation: _ringController,
      builder: (context, child) {
        final ringOpacity = isHelpActive
            ? 0.5 + (_ringController.value * 0.5)
            : 0.0;
        final ringScale = isHelpActive
            ? 1.0 + (_ringController.value * 0.15)
            : 1.0;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (isHelpActive) {
              ref.read(helpProvider.notifier).dismissTopic(widget.topicId);
            } else {
              ref.read(helpProvider.notifier).startTour(widget.topicId);
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animated ring when help mode is active
                if (isHelpActive)
                  Transform.scale(
                    scale: ringScale,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.accentColor.withValues(
                            alpha: ringOpacity,
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                // Icon with background when active
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isHelpActive
                        ? context.accentColor.withValues(alpha: 0.2)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    isHelpActive ? Icons.help : Icons.help_outline,
                    color: isHelpActive
                        ? context.accentColor
                        : context.textSecondary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// RICH TEXT PARSER - Parses **text** for colored highlights
// ============================================================================

/// Parses text with **highlighted** sections and returns styled TextSpans
/// Uses theme accent colors for highlights
/// Handles incomplete markdown during typing animation gracefully
class _RichTextParser {
  static List<TextSpan> parse(String text, {Color? highlightColor}) {
    final spans = <TextSpan>[];
    // Match complete **text** patterns OR incomplete **text at end of string
    final regex = RegExp(r'\*\*(.+?)\*\*|\*\*(.+)$');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Add text before the match
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.5,
              fontFamily: AppTheme.fontFamily,
              decoration: TextDecoration.none,
            ),
          ),
        );
      }

      // Add highlighted text (group 1 for complete, group 2 for incomplete)
      final highlightedText = match.group(1) ?? match.group(2);
      spans.add(
        TextSpan(
          text: highlightedText,
          style: TextStyle(
            color: highlightColor ?? AccentColors.orange,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w600,
            fontFamily: AppTheme.fontFamily,
            decoration: TextDecoration.none,
          ),
        ),
      );

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.5,
            fontFamily: AppTheme.fontFamily,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }

    return spans;
  }
}

// ============================================================================
// ANIMATED DOTTED INPUT BORDER - Custom InputBorder for TextFields
// ============================================================================

/// A custom InputBorder that draws an animated clockwise-moving dotted border.
/// Use this directly as the TextField's border property.
///
/// Example:
/// ```dart
/// TextField(
///   decoration: InputDecoration(
///     border: AnimatedDottedInputBorder(
///       animation: _controller,
///       color: AppTheme.primaryMagenta,
///     ),
///   ),
/// )
/// ```
class AnimatedDottedInputBorder extends InputBorder {
  final Animation<double> animation;
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;

  const AnimatedDottedInputBorder({
    required this.animation,
    this.color = AppTheme.primaryMagenta,
    this.strokeWidth = 2,
    this.dashLength = 6,
    this.gapLength = 4,
    this.borderRadius = 12,
    super.borderSide = BorderSide.none,
  });

  @override
  AnimatedDottedInputBorder copyWith({BorderSide? borderSide}) {
    return AnimatedDottedInputBorder(
      animation: animation,
      color: color,
      strokeWidth: strokeWidth,
      dashLength: dashLength,
      gapLength: gapLength,
      borderRadius: borderRadius,
      borderSide: borderSide ?? this.borderSide,
    );
  }

  @override
  bool get isOutline => true;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(strokeWidth);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRRect(
      RRect.fromRectAndRadius(
        rect.deflate(strokeWidth),
        Radius.circular(borderRadius - strokeWidth),
      ),
    );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(borderRadius)));
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    if (rect.width <= 0 || rect.height <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final r = borderRadius;
    final left = rect.left;
    final top = rect.top;
    final right = rect.right;
    final bottom = rect.bottom;

    // Calculate gap on top edge if label is floating
    final hasGap = gapStart != null && gapExtent > 0;
    final gapPadding = 4.0;
    final gapLeftX = hasGap ? left + gapStart - gapPadding : 0.0;
    final gapRightX = hasGap ? left + gapStart + gapExtent + gapPadding : 0.0;

    // Build a SINGLE continuous path (no moveTo except at start)
    // This ensures smooth animation around the entire border
    final path = Path();

    // Start at top-left corner end (where top edge begins)
    path.moveTo(left + r, top);

    if (hasGap) {
      // Top edge part 1: to gap
      path.lineTo(gapLeftX, top);
      // Jump over gap
      path.moveTo(gapRightX, top);
      // Top edge part 2: to top-right corner
      path.lineTo(right - r, top);
    } else {
      // Full top edge
      path.lineTo(right - r, top);
    }

    // Top-right arc (continuous from top edge)
    path.arcToPoint(Offset(right, top + r), radius: Radius.circular(r));

    // Right edge
    path.lineTo(right, bottom - r);

    // Bottom-right arc
    path.arcToPoint(Offset(right - r, bottom), radius: Radius.circular(r));

    // Bottom edge
    path.lineTo(left + r, bottom);

    // Bottom-left arc
    path.arcToPoint(Offset(left, bottom - r), radius: Radius.circular(r));

    // Left edge
    path.lineTo(left, top + r);

    // Top-left arc
    path.arcToPoint(Offset(left + r, top), radius: Radius.circular(r));

    // Draw animated dashes along each contiguous segment
    final animOffset = animation.value * (dashLength + gapLength) * 3;

    for (final metric in path.computeMetrics()) {
      final len = metric.length;
      if (len <= 0) continue;

      double dist = animOffset % (dashLength + gapLength);
      while (dist < len) {
        final start = dist;
        var end = start + dashLength;
        if (end > len) end = len;

        canvas.drawPath(metric.extractPath(start, end), paint);
        dist += dashLength + gapLength;
      }
    }
  }

  @override
  ShapeBorder scale(double t) => this;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is AnimatedDottedInputBorder &&
        other.color == color &&
        other.strokeWidth == strokeWidth &&
        other.dashLength == dashLength &&
        other.gapLength == gapLength &&
        other.borderRadius == borderRadius;
  }

  @override
  int get hashCode =>
      Object.hash(color, strokeWidth, dashLength, gapLength, borderRadius);
}

// ============================================================================
// ICO HIGHLIGHTED FIELD - Universal highlight wrapper for any control
// ============================================================================

/// A widget that highlights any control with an animated dotted border when
/// the associated help step is active.
///
/// For TextFields, use the [builder] to get animation and apply borders.
/// For any other widget, just provide a [child] - it will be wrapped with
/// an animated dotted border automatically when highlighted.
///
/// Features:
/// - Handles focus internally (auto-requests focus for focusable children)
/// - Works with any widget type (TextFields, buttons, cards, etc.)
/// - Animated marching-ants border effect when highlighted
/// - Configurable colors, stroke, and border radius
///
/// Example with TextField:
/// ```dart
/// IcoHighlightedField(
///   topicId: 'channel_creation',
///   stepId: 'channel_name',
///   builder: (context, isHighlighted, animation) => TextField(
///     decoration: InputDecoration(
///       border: isHighlighted
///         ? AnimatedDottedInputBorder(animation: animation)
///         : OutlineInputBorder(...),
///       enabledBorder: isHighlighted
///         ? AnimatedDottedInputBorder(animation: animation)
///         : OutlineInputBorder(...),
///     ),
///   ),
/// )
/// ```
///
/// Example with any widget:
/// ```dart
/// IcoHighlightedField(
///   topicId: 'settings',
///   stepId: 'privacy_toggle',
///   child: MyToggleWidget(),
/// )
/// ```
class IcoHighlightedField extends ConsumerStatefulWidget {
  /// Builder that receives highlight state and animation controller.
  /// Use this for TextFields where you need to apply the border to InputDecoration.
  final Widget Function(
    BuildContext context,
    bool isHighlighted,
    Animation<double> animation,
  )?
  builder;

  /// Simple child widget - will be wrapped with AnimatedDottedBorder when highlighted.
  final Widget? child;

  final String stepId;
  final String topicId;
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;

  /// Whether to auto-focus focusable children when this step becomes active.
  /// Defaults to true for TextFields (when using builder).
  final bool autoFocus;

  /// Optional FocusNode to control focus externally.
  /// If not provided, one will be created internally for auto-focus behavior.
  final FocusNode? focusNode;

  /// Padding between the child and the animated border.
  final EdgeInsets borderPadding;

  const IcoHighlightedField({
    super.key,
    this.builder,
    this.child,
    required this.stepId,
    required this.topicId,
    this.color = AppTheme.primaryMagenta,
    this.strokeWidth = 2,
    this.dashLength = 6,
    this.gapLength = 4,
    this.borderRadius = 12,
    this.autoFocus = true,
    this.focusNode,
    this.borderPadding = const EdgeInsets.all(4),
  }) : assert(
         builder != null || child != null,
         'Either builder or child must be provided',
       );

  @override
  ConsumerState<IcoHighlightedField> createState() =>
      _IcoHighlightedFieldState();
}

class _IcoHighlightedFieldState extends ConsumerState<IcoHighlightedField>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  FocusNode? _internalFocusNode;
  bool _wasHighlighted = false;

  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Create internal focus node if not provided externally
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  bool _isHighlighted(HelpState helpState) {
    if (helpState.activeTourId != widget.topicId) return false;
    final topic = HelpContent.getTopic(widget.topicId);
    if (topic == null) return false;
    if (helpState.currentStepIndex >= topic.steps.length) return false;
    return topic.steps[helpState.currentStepIndex].id == widget.stepId;
  }

  void _handleHighlightChange(bool isHighlighted) {
    // Auto-focus when becoming highlighted
    if (isHighlighted && !_wasHighlighted && widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.canRequestFocus) {
          _focusNode.requestFocus();
        }
      });
    }
    _wasHighlighted = isHighlighted;
  }

  @override
  Widget build(BuildContext context) {
    final helpState = ref.watch(helpProvider);
    final isHighlighted = _isHighlighted(helpState);

    // Handle focus changes
    _handleHighlightChange(isHighlighted);

    // For builder pattern (TextFields) - pass animation for InputBorder
    if (widget.builder != null) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return widget.builder!(context, isHighlighted, _controller);
        },
      );
    }

    // For child pattern - wrap with AnimatedDottedBorder
    return AnimatedDottedBorder(
      animation: _controller,
      isVisible: isHighlighted,
      color: widget.color,
      strokeWidth: widget.strokeWidth,
      dashLength: widget.dashLength,
      gapLength: widget.gapLength,
      borderRadius: widget.borderRadius,
      padding: widget.borderPadding,
      child: widget.child!,
    );
  }
}

// ============================================================================
// ANIMATED DOTTED BORDER - Wraps any widget with animated border
// ============================================================================

/// A widget that draws an animated dotted border around its child.
/// The border has a "marching ants" effect that moves clockwise.
///
/// Use this to highlight any widget, not just TextFields.
class AnimatedDottedBorder extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final bool isVisible;
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;
  final EdgeInsets padding;

  const AnimatedDottedBorder({
    super.key,
    required this.child,
    required this.animation,
    this.isVisible = true,
    this.color = AppTheme.primaryMagenta,
    this.strokeWidth = 2,
    this.dashLength = 6,
    this.gapLength = 4,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.all(4),
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return child;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          painter: _DottedBorderPainter(
            animation: animation,
            color: color,
            strokeWidth: strokeWidth,
            dashLength: dashLength,
            gapLength: gapLength,
            borderRadius: borderRadius,
            padding: padding,
          ),
          child: Padding(padding: padding, child: child),
        );
      },
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;
  final EdgeInsets padding;

  _DottedBorderPainter({
    required this.animation,
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
    required this.borderRadius,
    required this.padding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = strokeWidth + 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final path = Path()..addRRect(rrect);

    // Draw glow behind
    _drawDashedPath(canvas, path, glowPaint);

    // Draw main border
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final animOffset = animation.value * (dashLength + gapLength) * 3;

    for (final metric in path.computeMetrics()) {
      final len = metric.length;
      if (len <= 0) continue;

      double dist = animOffset % (dashLength + gapLength);
      while (dist < len) {
        final start = dist;
        var end = start + dashLength;
        if (end > len) end = len;

        canvas.drawPath(metric.extractPath(start, end), paint);
        dist += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DottedBorderPainter oldDelegate) => true;
}

// ============================================================================
// ICO SPEECH BUBBLE - Clean game-style dialogue box
// ============================================================================

class IcoSpeechBubbleWithArrow extends ConsumerStatefulWidget {
  final String text;
  final MeshBrainMood icoMood;
  final ArrowDirection? arrowDirection;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final String? nextLabel;
  final bool showBack;
  final bool showSkip;
  final int currentStep;
  final int totalSteps;

  const IcoSpeechBubbleWithArrow({
    super.key,
    required this.text,
    this.icoMood = MeshBrainMood.speaking,
    this.arrowDirection,
    this.onNext,
    this.onBack,
    this.onSkip,
    this.nextLabel,
    this.showBack = true,
    this.showSkip = true,
    this.currentStep = 1,
    this.totalSteps = 1,
  });

  @override
  ConsumerState<IcoSpeechBubbleWithArrow> createState() =>
      _IcoSpeechBubbleWithArrowState();
}

class _IcoSpeechBubbleWithArrowState
    extends ConsumerState<IcoSpeechBubbleWithArrow>
    with TickerProviderStateMixin {
  String _displayedText = '';
  Timer? _typingTimer;
  int _currentCharIndex = 0;
  late AnimationController _entryController;
  late AnimationController _glowController;
  late AnimationController _scanlineController;
  late Animation<double> _entry;
  late Animation<double> _glow;
  late Animation<double> _scanline;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _scanlineController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _entry = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _glow = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _scanline = Tween<double>(begin: 0, end: 1).animate(_scanlineController);

    _entryController.forward();
    _startTyping();
  }

  @override
  void didUpdateWidget(IcoSpeechBubbleWithArrow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _startTyping();
    }
  }

  void _startTyping() {
    _currentCharIndex = 0;
    _displayedText = '';
    _typingTimer?.cancel();

    _typingTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (_currentCharIndex < widget.text.length) {
        setState(() {
          _displayedText = widget.text.substring(0, _currentCharIndex + 1);
          _currentCharIndex++;
        });

        // Haptic feedback
        final helpState = ref.read(helpProvider);
        if (helpState.hapticFeedback) {
          HapticFeedback.selectionClick();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _completeTyping() {
    _typingTimer?.cancel();
    setState(() {
      _displayedText = widget.text;
      _currentCharIndex = widget.text.length;
    });
  }

  bool get _isTypingComplete => _currentCharIndex >= widget.text.length;

  @override
  void dispose() {
    _typingTimer?.cancel();
    _entryController.dispose();
    _glowController.dispose();
    _scanlineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final helpState = ref.watch(helpProvider);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _entry,
        _glowController,
        _scanlineController,
      ]),
      builder: (context, child) {
        return Transform.scale(
          scale: 0.9 + (_entry.value * 0.1),
          child: Opacity(
            opacity: _entry.value,
            child: GestureDetector(
              onTap: _isTypingComplete ? null : _completeTyping,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.92,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    // Animated outer glow like onboarding
                    BoxShadow(
                      color: context.accentColor.withValues(
                        alpha: _glow.value * 0.4,
                      ),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.card.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.accentColor.withValues(
                          alpha: _glow.value,
                        ),
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
                              color: context.accentColor.withValues(
                                alpha: 0.08,
                              ),
                            ),
                          ),
                        ),
                        // Content
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header - Character name
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: context.accentColor.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Ico avatar - properly sized with background
                                  SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      clipBehavior: Clip.none,
                                      children: [
                                        // Background circle
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: context.accentColor
                                                .withValues(alpha: 0.15),
                                            border: Border.all(
                                              color: context.accentColor
                                                  .withValues(alpha: 0.3),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        // Ico floating on top
                                        Positioned(
                                          top: -8,
                                          child: SizedBox(
                                            width: 64,
                                            height: 64,
                                            child: Material(
                                              type: MaterialType.transparency,
                                              child: MeshNodeBrain(
                                                mood: widget.icoMood,
                                                size: 64,
                                                showThoughtParticles: false,
                                                glowIntensity: 0.5,
                                                colors: [
                                                  context.accentColor,
                                                  Color.lerp(
                                                    context.accentColor,
                                                    AppTheme.primaryMagenta,
                                                    0.5,
                                                  )!,
                                                  Color.lerp(
                                                    context.accentColor,
                                                    AppTheme.graphBlue,
                                                    0.5,
                                                  )!,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ico',
                                    style: TextStyle(
                                      color: context.accentColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                      fontFamily: AppTheme.fontFamily,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Progress (if multi-step)
                                  if (widget.totalSteps > 1)
                                    Text(
                                      '${widget.currentStep}/${widget.totalSteps}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.4,
                                        ),
                                        fontSize: 11,
                                        fontFamily: AppTheme.fontFamily,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  // Haptic toggle
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      ref
                                          .read(helpProvider.notifier)
                                          .setHapticFeedback(
                                            !helpState.hapticFeedback,
                                          );
                                    },
                                    child: Icon(
                                      helpState.hapticFeedback
                                          ? Icons.vibration
                                          : Icons.mobile_off,
                                      size: 16,
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Message content
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: RichText(
                                text: TextSpan(
                                  children: _RichTextParser.parse(
                                    _displayedText,
                                    highlightColor: context.accentColor,
                                  ),
                                ),
                              ),
                            ),
                            // Action buttons
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: context.accentColor.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Back button
                                  if (widget.showBack && widget.onBack != null)
                                    GestureDetector(
                                      onTap: widget.onBack,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.arrow_back_ios,
                                            size: 14,
                                            color: context.accentColor
                                                .withValues(alpha: 0.7),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Back',
                                            style: TextStyle(
                                              color: context.accentColor
                                                  .withValues(alpha: 0.7),
                                              fontSize: 13,
                                              fontFamily: AppTheme.fontFamily,
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const Spacer(),
                                  // Skip button
                                  if (widget.showSkip && widget.onSkip != null)
                                    GestureDetector(
                                      onTap: widget.onSkip,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Text(
                                          'Skip',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.4,
                                            ),
                                            fontSize: 13,
                                            fontFamily: AppTheme.fontFamily,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                  // Next/Done button
                                  if (widget.onNext != null)
                                    GestureDetector(
                                      onTap: widget.onNext,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: context.accentColor,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          widget.nextLabel ?? 'Next',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: AppTheme.fontFamily,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

// ============================================================================
// ICO COACH MARK - Spotlight overlay for highlighting specific widgets
// ============================================================================

class IcoCoachMark extends StatefulWidget {
  final GlobalKey targetKey;
  final HelpStep step;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;
  final int currentStep;
  final int totalSteps;
  final double appBarHeight;

  const IcoCoachMark({
    super.key,
    required this.targetKey,
    required this.step,
    required this.onNext,
    this.onBack,
    required this.onSkip,
    this.currentStep = 1,
    this.totalSteps = 1,
    this.appBarHeight = 0,
  });

  @override
  State<IcoCoachMark> createState() => _IcoCoachMarkState();
}

class _IcoCoachMarkState extends State<IcoCoachMark> {
  Rect? _targetRect;
  Timer? _autoAdvanceTimer;
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateTargetRect();
      _setupAutoAdvance();
    });
  }

  void _calculateTargetRect() {
    final renderBox =
        widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      setState(() {
        _targetRect = Rect.fromLTWH(
          position.dx,
          position.dy,
          renderBox.size.width,
          renderBox.size.height,
        );
      });
    }
  }

  void _setupAutoAdvance() {
    if (widget.step.autoAdvanceDelay != null) {
      _autoAdvanceTimer = Timer(widget.step.autoAdvanceDelay!, () {
        if (mounted) widget.onNext();
      });
    }
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_targetRect == null) {
      return const SizedBox.shrink();
    }

    // Check keyboard visibility
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    _keyboardVisible = keyboardHeight > 100;

    final screenSize = MediaQuery.of(context).size;
    final targetInflated = _targetRect!.inflate(8);

    // Adjust target rect to be relative to this widget's coordinate space
    // (since this widget is positioned below the app bar)
    final adjustedTarget = Rect.fromLTRB(
      targetInflated.left,
      targetInflated.top - widget.appBarHeight,
      targetInflated.right,
      targetInflated.bottom - widget.appBarHeight,
    );

    // Available height is screen height minus app bar
    final availableHeight = screenSize.height - widget.appBarHeight;

    // Dimmed overlay color
    final dimColor = Colors.black.withValues(alpha: 0.6);

    // Only dim the area AROUND the target, not the whole screen
    // Each strip is tappable to dismiss help, but the target area passes through
    return Stack(
      fit: StackFit.expand,
      children: [
        // Top strip (above target) - tappable to dismiss
        if (adjustedTarget.top > 0)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: adjustedTarget.top,
            child: GestureDetector(
              onTap: widget.onSkip,
              behavior: HitTestBehavior.opaque,
              child: Container(color: dimColor),
            ),
          ),

        // Left strip (beside target) - tappable to dismiss
        if (adjustedTarget.left > 0)
          Positioned(
            left: 0,
            width: adjustedTarget.left,
            top: adjustedTarget.top,
            height: adjustedTarget.height,
            child: GestureDetector(
              onTap: widget.onSkip,
              behavior: HitTestBehavior.opaque,
              child: Container(color: dimColor),
            ),
          ),

        // Right strip (beside target) - tappable to dismiss
        if (adjustedTarget.right < screenSize.width)
          Positioned(
            left: adjustedTarget.right,
            right: 0,
            top: adjustedTarget.top,
            height: adjustedTarget.height,
            child: GestureDetector(
              onTap: widget.onSkip,
              behavior: HitTestBehavior.opaque,
              child: Container(color: dimColor),
            ),
          ),

        // Bottom strip (below target) - tappable to dismiss
        if (adjustedTarget.bottom < availableHeight)
          Positioned(
            left: 0,
            right: 0,
            top: adjustedTarget.bottom,
            bottom: 0,
            child: GestureDetector(
              onTap: widget.onSkip,
              behavior: HitTestBehavior.opaque,
              child: Container(color: dimColor),
            ),
          ),

        // Speech bubble - hide if keyboard is up
        if (!_keyboardVisible) _buildSpeechBubblePosition(context),
      ],
    );
  }

  Widget _buildSpeechBubblePosition(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bubbleHeight = 250.0;

    // Adjust target rect for this widget's coordinate space (below app bar)
    final adjustedTargetTop = _targetRect!.top - widget.appBarHeight;
    final adjustedTargetBottom = _targetRect!.bottom - widget.appBarHeight;
    final availableHeight = screenSize.height - widget.appBarHeight;

    final spaceAbove = adjustedTargetTop;
    final spaceBelow = availableHeight - adjustedTargetBottom;

    final shouldPositionAbove =
        spaceBelow < bubbleHeight && spaceAbove > spaceBelow;

    return Positioned(
      left: 16,
      right: 16,
      top: shouldPositionAbove ? null : adjustedTargetBottom + 20,
      bottom: shouldPositionAbove
          ? availableHeight - adjustedTargetTop + 20
          : null,
      child: IcoSpeechBubbleWithArrow(
        text: widget.step.bubbleText,
        icoMood: widget.step.icoMood,
        arrowDirection: widget.step.arrowDirection,
        onNext: widget.onNext,
        onBack: widget.step.canGoBack ? widget.onBack : null,
        onSkip: widget.step.canSkip ? widget.onSkip : null,
        showBack: widget.step.canGoBack,
        showSkip: widget.step.canSkip,
        currentStep: widget.currentStep,
        totalSteps: widget.totalSteps,
        nextLabel: widget.currentStep == widget.totalSteps ? 'Done' : 'Next',
      ),
    );
  }
}

// ============================================================================
// HELP TOUR CONTROLLER - Widget that manages entire tour flow
// ============================================================================

class HelpTourController extends ConsumerStatefulWidget {
  final String topicId;
  final Widget child;
  final Map<String, GlobalKey>? stepKeys;

  const HelpTourController({
    super.key,
    required this.topicId,
    required this.child,
    this.stepKeys,
  });

  @override
  ConsumerState<HelpTourController> createState() => _HelpTourControllerState();
}

class _HelpTourControllerState extends ConsumerState<HelpTourController> {
  @override
  Widget build(BuildContext context) {
    final helpState = ref.watch(helpProvider);
    final isActiveTour = helpState.activeTourId == widget.topicId;

    if (!isActiveTour) {
      return widget.child;
    }

    final topic = HelpContent.getTopic(widget.topicId);
    if (topic == null) {
      return widget.child;
    }

    final currentStep = topic.steps[helpState.currentStepIndex];
    final targetKey = widget.stepKeys?[currentStep.id];

    // Calculate app bar height to exclude from overlay
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final appBarHeight = safeAreaTop + kToolbarHeight;

    return Stack(
      children: [
        widget.child,
        // Show coach mark if target exists and is currently visible
        if (targetKey != null && targetKey.currentContext != null)
          Positioned(
            left: 0,
            right: 0,
            top: appBarHeight,
            bottom: 0,
            child: IcoCoachMark(
              targetKey: targetKey,
              step: currentStep,
              currentStep: helpState.currentStepIndex + 1,
              totalSteps: topic.steps.length,
              onNext: () => ref.read(helpProvider.notifier).nextStep(),
              onBack: helpState.currentStepIndex > 0
                  ? () => ref.read(helpProvider.notifier).previousStep()
                  : null,
              onSkip: () => ref.read(helpProvider.notifier).cancelTour(),
              appBarHeight: appBarHeight,
            ),
          )
        else
          // No target OR target not visible - show floating bubble
          Positioned(
            left: 0,
            right: 0,
            top: appBarHeight,
            bottom: 0,
            child: GestureDetector(
              onTap: () => ref.read(helpProvider.notifier).cancelTour(),
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: IcoSpeechBubbleWithArrow(
                    text: currentStep.bubbleText,
                    icoMood: currentStep.icoMood,
                    currentStep: helpState.currentStepIndex + 1,
                    totalSteps: topic.steps.length,
                    onNext: () => ref.read(helpProvider.notifier).nextStep(),
                    onBack:
                        currentStep.canGoBack && helpState.currentStepIndex > 0
                        ? () => ref.read(helpProvider.notifier).previousStep()
                        : null,
                    onSkip: currentStep.canSkip
                        ? () => ref.read(helpProvider.notifier).cancelTour()
                        : null,
                    showBack: currentStep.canGoBack,
                    showSkip: currentStep.canSkip,
                    nextLabel:
                        helpState.currentStepIndex == topic.steps.length - 1
                        ? 'Done'
                        : 'Next',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
