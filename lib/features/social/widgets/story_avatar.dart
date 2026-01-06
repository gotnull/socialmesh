import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/story.dart';

/// A circular avatar with a gradient ring for displaying story status.
///
/// Shows a colorful gradient ring for unviewed stories, gray ring for viewed,
/// and a plus icon for the "Add Story" button. The gradient ring rotates
/// with randomized speed and direction for a dynamic effect.
class StoryAvatar extends StatefulWidget {
  const StoryAvatar({
    super.key,
    required this.userId,
    this.avatarUrl,
    this.displayName,
    this.size = 64,
    this.hasUnviewed = false,
    this.isAddButton = false,
    this.showName = true,
    this.onTap,
  });

  /// User ID for avatar generation
  final String userId;

  /// Optional avatar URL
  final String? avatarUrl;

  /// Display name shown below avatar
  final String? displayName;

  /// Size of the avatar (default 64)
  final double size;

  /// Whether there are unviewed stories (shows gradient ring)
  final bool hasUnviewed;

  /// Whether this is the "Add Story" button
  final bool isAddButton;

  /// Whether to show the name below the avatar
  final bool showName;

  /// Callback when tapped
  final VoidCallback? onTap;

  @override
  State<StoryAvatar> createState() => _StoryAvatarState();
}

class _StoryAvatarState extends State<StoryAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final bool _rotateClockwise;

  // Random instance seeded with userId hash for consistent per-user randomness
  late final Random _random;

  @override
  void initState() {
    super.initState();

    // Seed random with userId for consistent animation per user
    _random = Random(widget.userId.hashCode);

    // Random duration between 3-8 seconds for variety
    final durationSeconds = 3 + _random.nextInt(6);

    // Random direction
    _rotateClockwise = _random.nextBool();

    _rotationController = AnimationController(
      duration: Duration(seconds: durationSeconds),
      vsync: this,
    );

    // Start rotating if has unviewed stories
    if (widget.hasUnviewed) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(StoryAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.hasUnviewed && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!widget.hasUnviewed && _rotationController.isAnimating) {
      _rotationController.stop();
      _rotationController.reset();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringWidth = widget.size * 0.05;
    final ringPadding = widget.size * 0.04;
    final totalSize = widget.size + (ringWidth + ringPadding) * 2;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: totalSize,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with ring
            SizedBox(
              width: totalSize,
              height: totalSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Gradient or gray ring (animated rotation for gradient)
                  if (!widget.isAddButton || widget.hasUnviewed)
                    widget.hasUnviewed
                        ? AnimatedBuilder(
                            animation: _rotationController,
                            builder: (context, child) {
                              // Calculate rotation angle based on direction
                              final angle = _rotateClockwise
                                  ? _rotationController.value * 2 * pi
                                  : -_rotationController.value * 2 * pi;
                              return Transform.rotate(
                                angle: angle,
                                child: child,
                              );
                            },
                            child: Container(
                              width: totalSize,
                              height: totalSize,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: [
                                    Color(0xFFFF6B6B), // Red/pink
                                    Color(0xFFFFE66D), // Yellow
                                    Color(0xFF4ECDC4), // Cyan
                                    Color(0xFFA855F7), // Purple
                                    Color(
                                      0xFFFF6B6B,
                                    ), // Back to red for seamless loop
                                  ],
                                  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width: totalSize,
                            height: totalSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.border,
                            ),
                          ),

                  // Inner white/dark circle to create ring effect
                  Container(
                    width: totalSize - ringWidth * 2,
                    height: totalSize - ringWidth * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.background,
                    ),
                  ),

                  // Actual avatar
                  SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: CircleAvatar(
                      radius: widget.size / 2,
                      backgroundImage: widget.avatarUrl != null
                          ? NetworkImage(widget.avatarUrl!)
                          : null,
                      backgroundColor: context.cardAlt,
                      child: widget.avatarUrl == null
                          ? Text(
                              (widget.displayName ?? 'U')[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: widget.size * 0.4,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                  ),

                  // Add button overlay
                  if (widget.isAddButton)
                    Positioned(
                      bottom: ringWidth,
                      right: ringWidth,
                      child: Container(
                        width: widget.size * 0.35,
                        height: widget.size * 0.35,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.brandGradientHorizontal,
                          border: Border.all(
                            color: context.background,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.add,
                          size: widget.size * 0.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Name label
            if (widget.showName) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: totalSize,
                child: Text(
                  widget.isAddButton
                      ? 'Your story'
                      : (widget.displayName ?? 'User'),
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A smaller story avatar for use in viewer lists
class SmallStoryAvatar extends StatelessWidget {
  const SmallStoryAvatar({
    super.key,
    required this.userId,
    this.avatarUrl,
    this.displayName,
    this.size = 40,
    this.onTap,
  });

  final String userId;
  final String? avatarUrl;
  final String? displayName;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundImage: avatarUrl != null
                ? NetworkImage(avatarUrl!)
                : null,
            backgroundColor: context.cardAlt,
            child: avatarUrl == null
                ? Text(
                    (displayName ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              displayName ?? 'User',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated story avatar with pulsing gradient for unviewed stories
class AnimatedStoryAvatar extends StatefulWidget {
  const AnimatedStoryAvatar({
    super.key,
    required this.storyGroup,
    this.size = 64,
    this.showName = true,
    this.onTap,
  });

  final StoryGroup storyGroup;
  final double size;
  final bool showName;
  final VoidCallback? onTap;

  @override
  State<AnimatedStoryAvatar> createState() => _AnimatedStoryAvatarState();
}

class _AnimatedStoryAvatarState extends State<AnimatedStoryAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    if (widget.storyGroup.hasUnviewed) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedStoryAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.storyGroup.hasUnviewed && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.storyGroup.hasUnviewed && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.storyGroup.profile;

    if (!widget.storyGroup.hasUnviewed) {
      return StoryAvatar(
        userId: widget.storyGroup.userId,
        avatarUrl: profile?.avatarUrl,
        displayName: profile?.displayName,
        size: widget.size,
        hasUnviewed: false,
        showName: widget.showName,
        onTap: widget.onTap,
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return StoryAvatar(
          userId: widget.storyGroup.userId,
          avatarUrl: profile?.avatarUrl,
          displayName: profile?.displayName,
          size: widget.size,
          hasUnviewed: true,
          showName: widget.showName,
          onTap: widget.onTap,
        );
      },
    );
  }
}
