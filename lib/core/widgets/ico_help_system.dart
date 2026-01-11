import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../help/help_content.dart';
import '../theme.dart';
import '../../features/onboarding/widgets/advisor_speech_bubble.dart';
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
                            AppTheme.primaryMagenta.withValues(alpha: 0.8),
                            AccentColors.cyan.withValues(alpha: 0.6),
                          ],
                        ),
                        border: Border.all(
                          color: AppTheme.primaryMagenta.withValues(alpha: 0.5),
                          width: 2,
                        ),
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
    );
  }
}

// ============================================================================
// ICO SPEECH BUBBLE - Enhanced version with arrow and positioning
// ============================================================================

class IcoSpeechBubbleWithArrow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ico mascot
        SizedBox(
          width: 120,
          height: 120,
          child: MeshNodeBrain(mood: icoMood, size: 100),
        ),
        const SizedBox(height: 16),

        // Speech bubble
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.darkBackground.withValues(alpha: 0.95),
                AppTheme.darkSurface.withValues(alpha: 0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryMagenta.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryMagenta.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress indicator
              if (totalSteps > 1) ...[
                Row(
                  children: [
                    Text(
                      'Step $currentStep of $totalSteps',
                      style: TextStyle(
                        color: AppTheme.primaryMagenta.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: currentStep / totalSteps,
                        backgroundColor: AppTheme.primaryMagenta.withValues(
                          alpha: 0.2,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryMagenta,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Message text
              AdvisorSpeechBubble(
                text: text,
                typewriterEffect: true,
                typingSpeed: 20,
                accentColor: AppTheme.primaryMagenta,
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  if (showBack && onBack != null)
                    TextButton.icon(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back'),
                      style: TextButton.styleFrom(
                        foregroundColor: AccentColors.cyan.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  // Skip button
                  if (showSkip && onSkip != null)
                    TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.5),
                      ),
                      child: const Text('Skip'),
                    ),

                  // Next/Done button
                  if (onNext != null)
                    ElevatedButton(
                      onPressed: onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryMagenta,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(nextLabel ?? 'Next'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
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
  late AnimationController _pulseController;
  Rect? _targetRect;
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

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
    _pulseController.dispose();
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_targetRect == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Backdrop with spotlight hole
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulseRadius = 8.0 + (_pulseController.value * 4);
            return ClipPath(
              clipper: _SpotlightClipper(_targetRect!.inflate(pulseRadius)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Container(color: Colors.black.withValues(alpha: 0.7)),
              ),
            );
          },
        ),

        // Glowing border around target
        Positioned(
          left: _targetRect!.left - 8,
          top: _targetRect!.top - 8,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulseRadius = 8.0 + (_pulseController.value * 4);
              return Container(
                width: _targetRect!.width + (pulseRadius * 2),
                height: _targetRect!.height + (pulseRadius * 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryMagenta.withValues(
                      alpha: 0.3 + (_pulseController.value * 0.4),
                    ),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryMagenta.withValues(
                        alpha: 0.2 + (_pulseController.value * 0.3),
                      ),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Speech bubble positioned based on available space
        _buildSpeechBubblePosition(context),
      ],
    );
  }

  Widget _buildSpeechBubblePosition(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bubbleHeight = 350.0; // Approximate bubble height

    // Determine best position for bubble
    final spaceAbove = _targetRect!.top;
    final spaceBelow = screenSize.height - _targetRect!.bottom;

    final shouldPositionAbove =
        spaceBelow < bubbleHeight && spaceAbove > spaceBelow;

    return Positioned(
      left: 16,
      right: 16,
      top: shouldPositionAbove ? null : _targetRect!.bottom + 24,
      bottom: shouldPositionAbove
          ? screenSize.height - _targetRect!.top + 24
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

class _SpotlightClipper extends CustomClipper<Path> {
  final Rect spotlight;

  _SpotlightClipper(this.spotlight);

  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final spotlightPath = Path()
      ..addRRect(RRect.fromRectAndRadius(spotlight, const Radius.circular(12)));

    return Path.combine(PathOperation.difference, path, spotlightPath);
  }

  @override
  bool shouldReclip(covariant _SpotlightClipper oldClipper) {
    return oldClipper.spotlight != spotlight;
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
