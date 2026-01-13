import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/widgets/snappable.dart';

/// A widget that wraps signal cards and applies the Thanos snap effect
/// when dismissed or when TTL expires.
///
/// Features:
/// - Snap effect on swipe-to-hide
/// - Auto-snap when signal TTL expires
/// - Haptic feedback
/// - Callbacks for completion
class SnappableSignalWrapper extends StatefulWidget {
  const SnappableSignalWrapper({
    super.key,
    required this.signalId,
    required this.child,
    this.expiresAt,
    this.onSnapped,
    this.snapOnExpiry = true,
    this.snapDuration = const Duration(milliseconds: 2500),
    this.snapOffset = const Offset(80, -40),
  });

  /// Unique identifier for the signal
  final String signalId;

  /// The child widget to wrap (signal card)
  final Widget child;

  /// When the signal expires (for auto-snap)
  final DateTime? expiresAt;

  /// Called when snap animation completes
  final VoidCallback? onSnapped;

  /// Whether to auto-snap when TTL expires
  final bool snapOnExpiry;

  /// Duration of snap animation
  final Duration snapDuration;

  /// Direction particles fly
  final Offset snapOffset;

  @override
  State<SnappableSignalWrapper> createState() => SnappableSignalWrapperState();
}

class SnappableSignalWrapperState extends State<SnappableSignalWrapper> {
  final GlobalKey<SnappableState> _snappableKey = GlobalKey<SnappableState>();
  Timer? _expiryTimer;
  bool _hasSnapped = false;

  @override
  void initState() {
    super.initState();
    _setupExpiryTimer();
  }

  @override
  void didUpdateWidget(SnappableSignalWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expiresAt != oldWidget.expiresAt) {
      _setupExpiryTimer();
    }
  }

  void _setupExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = null;

    if (!widget.snapOnExpiry || widget.expiresAt == null) return;

    final remaining = widget.expiresAt!.difference(DateTime.now());

    if (remaining.isNegative) {
      // Already expired - snap immediately (slight delay for rendering)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_hasSnapped) snap();
      });
    } else {
      // Schedule snap for when it expires
      _expiryTimer = Timer(remaining, () {
        if (mounted && !_hasSnapped) snap();
      });
    }
  }

  /// Trigger the snap effect programmatically
  void snap() {
    if (_hasSnapped) return;
    _hasSnapped = true;
    _snappableKey.currentState?.snap();
  }

  /// Reset the widget (undo snap)
  void reset() {
    _hasSnapped = false;
    _snappableKey.currentState?.reset();
    _setupExpiryTimer();
  }

  /// Check if widget has been snapped
  bool get isSnapped => _hasSnapped;

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Snappable(
      key: _snappableKey,
      duration: widget.snapDuration,
      offset: widget.snapOffset,
      randomDislocationOffset: const Offset(30, 20),
      numberOfBuckets: 20,
      onSnapped: () {
        widget.onSnapped?.call();
      },
      child: widget.child,
    );
  }
}

/// A swipeable signal item with snap effect on hide.
///
/// Combines SwipeableSignalItem behavior with Snappable effect.
/// When swiping left to hide, the card snaps away instead of just disappearing.
class SnapSwipeableSignalItem extends StatefulWidget {
  const SnapSwipeableSignalItem({
    super.key,
    required this.signalId,
    required this.child,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    this.expiresAt,
    this.isBookmarked = false,
    this.rightActionIcon = Icons.bookmark_add_rounded,
    this.rightActionIconActive = Icons.bookmark_remove_rounded,
    this.leftActionIcon = Icons.visibility_off_rounded,
    this.leftActionLabel = 'Hide',
    this.borderRadius = 16.0,
    this.hintKey = 'signal_swipe_hint_seen',
    this.snapOnExpiry = true,
    this.onExpired,
  });

  final String signalId;
  final Widget child;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;
  final DateTime? expiresAt;
  final bool isBookmarked;
  final IconData rightActionIcon;
  final IconData rightActionIconActive;
  final IconData leftActionIcon;
  final String leftActionLabel;
  final double borderRadius;
  final String hintKey;
  final bool snapOnExpiry;
  final VoidCallback? onExpired;

  @override
  State<SnapSwipeableSignalItem> createState() =>
      _SnapSwipeableSignalItemState();
}

class _SnapSwipeableSignalItemState extends State<SnapSwipeableSignalItem>
    with TickerProviderStateMixin {
  final GlobalKey<SnappableState> _snappableKey = GlobalKey<SnappableState>();
  late AnimationController _swipeController;
  late AnimationController _hintController;
  late AnimationController _fadeController;
  late Animation<double> _hintAnimation;

  Timer? _expiryTimer;
  double _dragExtent = 0;
  static const _threshold = 80.0;
  bool _hasTriggeredHaptic = false;
  bool _isSnapping = false;
  bool _showingHint = false;

  // Track shown hints per session
  static final Set<String> _shownHintKeys = {};

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
      value: 1.0,
    );

    _hintController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

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
        setState(() => _dragExtent = _hintAnimation.value);
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

    _maybeShowHint();
    _setupExpiryTimer();
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

  void _setupExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = null;

    if (!widget.snapOnExpiry || widget.expiresAt == null) return;

    final remaining = widget.expiresAt!.difference(DateTime.now());

    if (remaining.isNegative) {
      // Already expired
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isSnapping) _triggerExpirySnap();
      });
    } else {
      _expiryTimer = Timer(remaining, () {
        if (mounted && !_isSnapping) _triggerExpirySnap();
      });
    }
  }

  void _triggerExpirySnap() {
    if (_isSnapping) return;
    _isSnapping = true;
    _snappableKey.currentState?.snap();
  }

  @override
  void didUpdateWidget(SnapSwipeableSignalItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expiresAt != oldWidget.expiresAt) {
      _setupExpiryTimer();
    }
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _hintController.dispose();
    _fadeController.dispose();
    _expiryTimer?.cancel();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_showingHint || _isSnapping) {
      _hintController.stop();
      setState(() => _showingHint = false);
      return;
    }

    setState(() {
      _dragExtent += details.delta.dx;
      _dragExtent = _dragExtent.clamp(-150.0, 150.0);
    });

    if (!_hasTriggeredHaptic && _dragExtent.abs() >= _threshold) {
      _hasTriggeredHaptic = true;
    } else if (_hasTriggeredHaptic && _dragExtent.abs() < _threshold) {
      _hasTriggeredHaptic = false;
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_showingHint || _isSnapping) return;

    if (_dragExtent >= _threshold) {
      // Swipe right - bookmark (no snap)
      widget.onSwipeRight();
      _snapBack();
    } else if (_dragExtent <= -_threshold) {
      // Swipe left - hide with SNAP effect!
      _isSnapping = true;
      // Animate drag extent back to 0 and fade out whole widget
      _fadeController.reverse();
      final startExtent = _dragExtent;
      _swipeController.reset();
      _swipeController.addListener(() {
        if (mounted) {
          setState(
            () => _dragExtent = startExtent * (1 - _swipeController.value),
          );
        }
      });
      _swipeController.forward();
      _snappableKey.currentState?.snap();
    } else {
      _snapBack();
    }

    _hasTriggeredHaptic = false;
  }

  void _snapBack() {
    final startExtent = _dragExtent;
    _swipeController.reset();

    void animateBack() {
      if (!mounted) return;
      setState(() {
        _dragExtent = startExtent * (1 - _swipeController.value);
      });
    }

    _swipeController.addListener(animateBack);
    _swipeController.forward().then((_) {
      _swipeController.removeListener(animateBack);
      if (mounted) {
        setState(() => _dragExtent = 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragExtent / _threshold).clamp(-1.0, 1.0);
    final rightProgress = progress.clamp(0.0, 1.0);
    final leftProgress = (-progress).clamp(0.0, 1.0);

    final rightColor = Colors.amber;
    final leftColor = Colors.grey;
    final radius = BorderRadius.circular(widget.borderRadius);

    // Only fade action backgrounds when snapping, not the whole thing
    final actionOpacity = _isSnapping ? _fadeController.value : 1.0;

    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: AnimatedBuilder(
        animation: _fadeController,
        builder: (context, child) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Right action background (bookmark)
              if (_dragExtent > 0)
                Positioned.fill(
                  child: Opacity(
                    opacity: actionOpacity,
                    child: ClipRRect(
                      borderRadius: radius,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.center,
                            colors: [
                              rightColor.withValues(
                                alpha: 0.2 + rightProgress * 0.2,
                              ),
                              rightColor.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: _SwipeActionIndicator(
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
                ),

              // Left action background (hide)
              if (_dragExtent < 0)
                Positioned.fill(
                  child: Opacity(
                    opacity: actionOpacity,
                    child: ClipRRect(
                      borderRadius: radius,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.center,
                            colors: [
                              leftColor.withValues(
                                alpha: 0.2 + leftProgress * 0.2,
                              ),
                              leftColor.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 20),
                            child: _SwipeActionIndicator(
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
                ),

              // Main content with snap effect
              Transform.translate(
                offset: Offset(_dragExtent, 0),
                child: Snappable(
                  key: _snappableKey,
                  duration: const Duration(milliseconds: 2500),
                  offset: const Offset(100, -50),
                  randomDislocationOffset: const Offset(40, 25),
                  numberOfBuckets: 20,
                  onSnapped: () {
                    // Call the onSwipeLeft after snap completes (for hide action)
                    // or onExpired for TTL expiry
                    if (_isSnapping) {
                      widget.onSwipeLeft();
                    } else {
                      widget.onExpired?.call();
                    }
                  },
                  child: widget.child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SwipeActionIndicator extends StatelessWidget {
  const _SwipeActionIndicator({
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
