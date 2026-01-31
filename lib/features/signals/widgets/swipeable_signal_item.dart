// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme.dart';

/// A swipeable signal item that reveals actions on swipe.
///
/// Features:
/// - Swipe right to bookmark/save
/// - Swipe left to hide
/// - Visual hints for discoverability (smooth animation)
/// - Matching border radius with card
class SwipeableSignalItem extends StatefulWidget {
  const SwipeableSignalItem({
    required this.child,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    this.isBookmarked = false,
    this.rightActionIcon = Icons.bookmark_add_rounded,
    this.rightActionIconActive = Icons.bookmark_remove_rounded,
    this.leftActionIcon = Icons.visibility_off_rounded,
    this.leftActionLabel = 'Hide',
    this.rightActionColor,
    this.leftActionColor,
    this.borderRadius = 16.0,
    this.hintKey = 'signal_swipe_hint_seen',
    super.key,
  });

  final Widget child;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;
  final bool isBookmarked;
  final IconData rightActionIcon;
  final IconData rightActionIconActive;
  final IconData leftActionIcon;
  final String leftActionLabel;
  final Color? rightActionColor;
  final Color? leftActionColor;
  final double borderRadius;

  /// SharedPreferences key for tracking if hint has been shown.
  /// Use different keys for different contexts (e.g., normal vs hidden view).
  final String hintKey;

  @override
  State<SwipeableSignalItem> createState() => _SwipeableSignalItemState();
}

class _SwipeableSignalItemState extends State<SwipeableSignalItem>
    with TickerProviderStateMixin {
  late AnimationController _snapBackController;
  late AnimationController _hintController;
  late Animation<double> _hintAnimation;

  double _dragExtent = 0;
  static const _threshold = 80.0;
  bool _hasTriggeredHaptic = false;

  // For hint animation - track shown hints per key
  static final Set<String> _shownHintKeys = {};
  bool _showingHint = false;

  @override
  void initState() {
    super.initState();
    _snapBackController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Smooth hint animation controller
    _hintController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    // Smooth sequence: 0->40 (right peek) -> -40 (left peek) -> 0 (back)
    _hintAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 45.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 45.0,
          end: -45.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -45.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 25,
      ),
    ]).animate(_hintController);

    _hintAnimation.addListener(() {
      if (_showingHint && mounted) {
        setState(() {
          _dragExtent = _hintAnimation.value;
        });
      }
    });

    _hintController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _showingHint = false;
            _dragExtent = 0;
          });
        }
      }
    });

    // Show hint animation once per session
    _maybeShowHint();
  }

  Future<void> _maybeShowHint() async {
    if (_shownHintKeys.contains(widget.hintKey)) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenHint = prefs.getBool(widget.hintKey) ?? false;

    if (!hasSeenHint && mounted) {
      _shownHintKeys.add(widget.hintKey);
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;

      setState(() => _showingHint = true);
      _hintController.forward(from: 0);

      await prefs.setBool(widget.hintKey, true);
    }
  }

  @override
  void dispose() {
    _snapBackController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_showingHint) {
      // Cancel hint if user starts dragging
      _hintController.stop();
      setState(() => _showingHint = false);
    }

    setState(() {
      _dragExtent += details.delta.dx;
      _dragExtent = _dragExtent.clamp(-150.0, 150.0);
    });

    // Haptic feedback when crossing threshold
    if (!_hasTriggeredHaptic && _dragExtent.abs() >= _threshold) {
      HapticFeedback.selectionClick();
      _hasTriggeredHaptic = true;
    } else if (_hasTriggeredHaptic && _dragExtent.abs() < _threshold) {
      _hasTriggeredHaptic = false;
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_showingHint) return;

    if (_dragExtent >= _threshold) {
      // Swipe right - bookmark
      HapticFeedback.mediumImpact();
      widget.onSwipeRight();
    } else if (_dragExtent <= -_threshold) {
      // Swipe left - hide
      HapticFeedback.mediumImpact();
      widget.onSwipeLeft();
    }

    // Animate back to center
    final startExtent = _dragExtent;
    _snapBackController.reset();

    void animateBack() {
      if (!mounted) return;
      setState(() {
        _dragExtent = startExtent * (1 - _snapBackController.value);
      });
    }

    _snapBackController.addListener(animateBack);
    _snapBackController.forward().then((_) {
      _snapBackController.removeListener(animateBack);
      if (mounted) {
        setState(() => _dragExtent = 0);
      }
    });

    _hasTriggeredHaptic = false;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragExtent / _threshold).clamp(-1.0, 1.0);
    final rightProgress = progress.clamp(0.0, 1.0);
    final leftProgress = (-progress).clamp(0.0, 1.0);

    final rightColor = widget.rightActionColor ?? AccentColors.yellow;
    final leftColor = widget.leftActionColor ?? Colors.grey;
    final radius = BorderRadius.circular(widget.borderRadius);

    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        children: [
          // Right action background (bookmark) - revealed when swiping right
          if (_dragExtent > 0)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: radius,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.center,
                      colors: [
                        rightColor.withValues(alpha: 0.2 + rightProgress * 0.2),
                        rightColor.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: _ActionIndicator(
                        progress: rightProgress,
                        color: rightColor,
                        icon: widget.isBookmarked
                            ? widget.rightActionIconActive
                            : widget.rightActionIcon,
                        label: widget.isBookmarked ? 'Unsave' : 'Save',
                        isHint: _showingHint,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Left action background (hide) - revealed when swiping left
          if (_dragExtent < 0)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: radius,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.center,
                      colors: [
                        leftColor.withValues(alpha: 0.2 + leftProgress * 0.2),
                        leftColor.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: _ActionIndicator(
                        progress: leftProgress,
                        color: leftColor,
                        icon: widget.leftActionIcon,
                        label: widget.leftActionLabel,
                        isHint: _showingHint,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Main content
          Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// Action indicator shown during swipe
class _ActionIndicator extends StatelessWidget {
  const _ActionIndicator({
    required this.progress,
    required this.color,
    required this.icon,
    required this.label,
    this.isHint = false,
  });

  final double progress;
  final Color color;
  final IconData icon;
  final String label;
  final bool isHint;

  @override
  Widget build(BuildContext context) {
    final effectiveProgress = isHint ? 0.5 : progress;
    final isTriggered = progress >= 1.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 100),
      opacity: effectiveProgress.clamp(0.0, 1.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: isTriggered ? 1.2 : (0.6 + effectiveProgress * 0.4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isTriggered ? 1.0 : 0.9),
                shape: BoxShape.circle,
                boxShadow: isTriggered
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 100),
            opacity: effectiveProgress > 0.3 ? 1.0 : 0.0,
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
