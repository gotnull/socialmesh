// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Shimmer loading skeleton for signal cards.
/// Displays placeholder shapes matching the signal card layout.
class SignalCardSkeleton extends StatefulWidget {
  const SignalCardSkeleton({super.key});

  @override
  State<SignalCardSkeleton> createState() => _SignalCardSkeletonState();
}

class _SignalCardSkeletonState extends State<SignalCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.border.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header skeleton
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _shimmerBox(40, 40, isCircle: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _shimmerBox(120, 14),
                          const SizedBox(height: 6),
                          _shimmerBox(80, 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content skeleton
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(double.infinity, 14),
                    const SizedBox(height: 8),
                    _shimmerBox(200, 14),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Footer skeleton
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _shimmerBox(80, 12),
                    const Spacer(),
                    _shimmerBox(40, 12),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox(double width, double height, {bool isCircle = false}) {
    final baseColor = context.border.withValues(alpha: 0.3);
    final highlightColor = context.border.withValues(alpha: 0.1);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: isCircle ? null : BorderRadius.circular(4),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [baseColor, highlightColor, baseColor],
          stops: [
            (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
            _shimmerAnimation.value.clamp(0.0, 1.0),
            (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for signal list loading state
class SignalListSkeleton extends StatelessWidget {
  const SignalListSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: index == 0 ? 16 : 0,
            bottom: 12,
          ),
          child: const SignalCardSkeleton(),
        ),
      ),
    );
  }
}
