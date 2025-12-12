import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/floating_icons_background.dart';

// Re-export the shared background widget for convenience
export '../../../core/widgets/floating_icons_background.dart';

/// Connecting animation with status text and optional cancel button.
/// Uses the floating icons background centered on screen.
class ConnectingAnimation extends StatelessWidget {
  final String statusText;
  final VoidCallback? onCancel;
  final bool showCancel;

  const ConnectingAnimation({
    super.key,
    this.statusText = 'Connecting...',
    this.onCancel,
    this.showCancel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Floating icons background
        const Positioned.fill(child: FloatingIconsBackground()),

        // Center content
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status text
              Text(
                statusText,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              // Animated dots
              const _AnimatedDots(),
              if (showCancel) ...[
                const SizedBox(height: 32),
                TextButton(
                  onPressed: onCancel,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Alias for FloatingIconsBackground for backward compatibility
typedef ConnectingAnimationBackground = FloatingIconsBackground;

class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots();

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final progress = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = math.sin(progress * math.pi);

            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.accentColor.withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}
