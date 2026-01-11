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
    )..repeat(reverse: true);
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
// RICH TEXT PARSER - Parses **text** for colored highlights
// ============================================================================

/// Parses text with **highlighted** sections and returns styled TextSpans
/// Uses theme accent colors for highlights
class _RichTextParser {
  static List<TextSpan> parse(String text, {Color? highlightColor}) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
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
            ),
          ),
        );
      }

      // Add highlighted text
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            color: highlightColor ?? AccentColors.orange,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w600,
            fontFamily: AppTheme.fontFamily,
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
          ),
        ),
      );
    }

    return spans;
  }
}

// ============================================================================
// ANIMATED DOTTED BORDER - For highlighting target widgets
// ============================================================================

class AnimatedDottedBorder extends StatefulWidget {
  final Widget child;
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;

  const AnimatedDottedBorder({
    super.key,
    required this.child,
    this.color = AppTheme.primaryMagenta,
    this.strokeWidth = 2,
    this.dashLength = 8,
    this.gapLength = 4,
    this.borderRadius = 12,
  });

  @override
  State<AnimatedDottedBorder> createState() => _AnimatedDottedBorderState();
}

class _AnimatedDottedBorderState extends State<AnimatedDottedBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
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
      builder: (context, child) {
        return CustomPaint(
          painter: _DottedBorderPainter(
            progress: _controller.value,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
            dashLength: widget.dashLength,
            gapLength: widget.gapLength,
            borderRadius: widget.borderRadius,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;

  _DottedBorderPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rect);
    final pathMetrics = path.computeMetrics();

    for (final metric in pathMetrics) {
      final totalLength = metric.length;
      final dashCount = (totalLength / (dashLength + gapLength)).ceil();
      final offset = progress * (dashLength + gapLength);

      for (int i = 0; i < dashCount; i++) {
        final start = (i * (dashLength + gapLength) + offset) % totalLength;
        final end = (start + dashLength) % totalLength;

        if (end > start) {
          final dashPath = metric.extractPath(start, end);
          canvas.drawPath(dashPath, paint);
        } else {
          // Handle wrap-around
          final dashPath1 = metric.extractPath(start, totalLength);
          final dashPath2 = metric.extractPath(0, end);
          canvas.drawPath(dashPath1, paint);
          canvas.drawPath(dashPath2, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
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
    with SingleTickerProviderStateMixin {
  String _displayedText = '';
  Timer? _typingTimer;
  int _currentCharIndex = 0;
  late AnimationController _entryController;
  late Animation<double> _entry;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _entry = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
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

  @override
  void dispose() {
    _typingTimer?.cancel();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final helpState = ref.watch(helpProvider);

    return AnimatedBuilder(
      animation: _entry,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.9 + (_entry.value * 0.1),
          child: Opacity(
            opacity: _entry.value,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.92,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
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
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Small Ico avatar
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryMagenta.withValues(
                              alpha: 0.2,
                            ),
                          ),
                          child: MeshNodeBrain(mood: widget.icoMood, size: 28),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'ICO',
                          style: TextStyle(
                            color: AppTheme.primaryMagenta,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                        const Spacer(),
                        // Progress (if multi-step)
                        if (widget.totalSteps > 1)
                          Text(
                            '${widget.currentStep}/${widget.totalSteps}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                        const SizedBox(width: 8),
                        // Haptic toggle
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(helpProvider.notifier)
                                .setHapticFeedback(!helpState.hapticFeedback);
                          },
                          child: Icon(
                            helpState.hapticFeedback
                                ? Icons.vibration
                                : Icons.mobile_off,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.4),
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
                          highlightColor: AccentColors.orange,
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
                          color: Colors.white.withValues(alpha: 0.1),
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
                                  color: AccentColors.cyan.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Back',
                                  style: TextStyle(
                                    color: AccentColors.cyan.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 13,
                                    fontFamily: AppTheme.fontFamily,
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
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 13,
                                  fontFamily: AppTheme.fontFamily,
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
                                color: AppTheme.primaryMagenta,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.nextLabel ?? 'Next',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: AppTheme.fontFamily,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
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

  const IcoCoachMark({
    super.key,
    required this.targetKey,
    required this.step,
    required this.onNext,
    this.onBack,
    required this.onSkip,
    this.currentStep = 1,
    this.totalSteps = 1,
  });

  @override
  State<IcoCoachMark> createState() => _IcoCoachMarkState();
}

class _IcoCoachMarkState extends State<IcoCoachMark>
    with SingleTickerProviderStateMixin {
  late AnimationController _borderAnimController;
  Rect? _targetRect;
  Timer? _autoAdvanceTimer;
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _borderAnimController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

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
    _borderAnimController.dispose();
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

    return Stack(
      children: [
        // Semi-transparent backdrop (no blur - cleaner look)
        GestureDetector(
          onTap: () {}, // Absorb taps
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),

        // Cutout for the target widget (let it be interactive)
        Positioned(
          left: _targetRect!.left - 4,
          top: _targetRect!.top - 4,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            child: Container(
              width: _targetRect!.width + 8,
              height: _targetRect!.height + 8,
              color: Colors.transparent,
            ),
          ),
        ),

        // Animated dotted border around target
        Positioned(
          left: _targetRect!.left - 6,
          top: _targetRect!.top - 6,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _borderAnimController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(_targetRect!.width + 12, _targetRect!.height + 12),
                  painter: _AnimatedDottedBorderPainter(
                    progress: _borderAnimController.value,
                    color: AppTheme.primaryMagenta,
                    strokeWidth: 2,
                    dashLength: 8,
                    gapLength: 6,
                    borderRadius: 8,
                  ),
                );
              },
            ),
          ),
        ),

        // Speech bubble - hide if keyboard is up
        if (!_keyboardVisible) _buildSpeechBubblePosition(context),
      ],
    );
  }

  Widget _buildSpeechBubblePosition(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bubbleHeight = 250.0; // Approximate bubble height

    // Determine best position for bubble
    final spaceAbove = _targetRect!.top;
    final spaceBelow = screenSize.height - _targetRect!.bottom;

    final shouldPositionAbove =
        spaceBelow < bubbleHeight && spaceAbove > spaceBelow;

    return Positioned(
      left: 16,
      right: 16,
      top: shouldPositionAbove ? null : _targetRect!.bottom + 20,
      bottom: shouldPositionAbove
          ? screenSize.height - _targetRect!.top + 20
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

class _AnimatedDottedBorderPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;

  _AnimatedDottedBorderPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rect);
    final pathMetrics = path.computeMetrics().first;
    final totalLength = pathMetrics.length;

    // Animate the dashes moving clockwise
    final offset = progress * (dashLength + gapLength) * 2;

    double distance = offset;
    while (distance < totalLength) {
      final start = distance % totalLength;
      final end = (start + dashLength).clamp(0.0, totalLength);

      if (end > start) {
        final dashPath = pathMetrics.extractPath(start, end);
        canvas.drawPath(dashPath, paint);
      }

      distance += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedDottedBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
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

    return Stack(
      children: [
        widget.child,
        if (targetKey != null && targetKey.currentContext != null)
          IcoCoachMark(
            targetKey: targetKey,
            step: currentStep,
            currentStep: helpState.currentStepIndex + 1,
            totalSteps: topic.steps.length,
            onNext: () => ref.read(helpProvider.notifier).nextStep(),
            onBack: helpState.currentStepIndex > 0
                ? () => ref.read(helpProvider.notifier).previousStep()
                : null,
            onSkip: () => _showSkipDialog(context),
          )
        else
          // No target - show floating bubble
          Positioned.fill(
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
                      ? () => _showSkipDialog(context)
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
      ],
    );
  }

  void _showSkipDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Skip Help?'),
        content: const Text(
          'Would you like to skip this help tour?\n\nYou can always replay it later from the Help Center.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Tour'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(helpProvider.notifier)
                  .dismissTopic(widget.topicId, dontShowAgain: false);
            },
            child: Text(
              'Skip for Now',
              style: TextStyle(color: AppTheme.primaryMagenta),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(helpProvider.notifier)
                  .dismissTopic(widget.topicId, dontShowAgain: true);
            },
            child: Text(
              "Don't Show Again",
              style: TextStyle(color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }
}
