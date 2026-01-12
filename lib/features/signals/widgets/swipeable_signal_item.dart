import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme.dart';

/// A swipeable signal item that reveals actions on swipe.
///
/// Features:
/// - Swipe right to bookmark/save
/// - Swipe left to hide
/// - Visual hints for discoverability
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
    this.rightActionColor,
    this.leftActionColor,
    this.borderRadius = 16.0,
    super.key,
  });

  final Widget child;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;
  final bool isBookmarked;
  final IconData rightActionIcon;
  final IconData rightActionIconActive;
  final IconData leftActionIcon;
  final Color? rightActionColor;
  final Color? leftActionColor;
  final double borderRadius;

  @override
  State<SwipeableSignalItem> createState() => _SwipeableSignalItemState();
}

class _SwipeableSignalItemState extends State<SwipeableSignalItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  double _dragExtent = 0;
  static const _threshold = 80.0;
  bool _hasTriggeredHaptic = false;

  // For hint animation
  static bool _hasShownHint = false;
  bool _showingHint = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Show hint animation once per session
    _maybeShowHint();
  }

  Future<void> _maybeShowHint() async {
    if (_hasShownHint) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenHint = prefs.getBool('signal_swipe_hint_seen') ?? false;

    if (!hasSeenHint && mounted) {
      _hasShownHint = true;
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      setState(() => _showingHint = true);

      // Animate hint - peek right then left
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() => _dragExtent = 40);

      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _dragExtent = -40);

      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() {
        _dragExtent = 0;
        _showingHint = false;
      });

      await prefs.setBool('signal_swipe_hint_seen', true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_showingHint) return;

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
    _slideAnimation = Tween<Offset>(
      begin: Offset(_dragExtent / (context.size?.width ?? 300), 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _dragExtent = 0;
        });
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
          if (_dragExtent > 0 || _showingHint && _dragExtent > 0)
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
          if (_dragExtent < 0 || _showingHint && _dragExtent < 0)
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
                        label: 'Hide',
                        isHint: _showingHint,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Main content
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final offset = _controller.isAnimating
                  ? _slideAnimation.value
                  : Offset(_dragExtent / (context.size?.width ?? 300), 0);
              return Transform.translate(
                offset: Offset(offset.dx * (context.size?.width ?? 300), 0),
                child: child,
              );
            },
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
