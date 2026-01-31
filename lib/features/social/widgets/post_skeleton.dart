// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Skeleton loader for PostCard
class PostSkeleton extends StatefulWidget {
  const PostSkeleton({super.key});

  @override
  State<PostSkeleton> createState() => _PostSkeletonState();
}

class _PostSkeletonState extends State<PostSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: context.card,
            border: Border(bottom: BorderSide(color: context.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _buildShimmer(
                      context,
                      width: 40,
                      height: 40,
                      borderRadius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildShimmer(context, width: 120, height: 14),
                          const SizedBox(height: 6),
                          _buildShimmer(context, width: 80, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Image
              _buildShimmer(context, width: double.infinity, height: 300),

              // Actions bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _buildShimmer(context, width: 24, height: 24),
                    const SizedBox(width: 16),
                    _buildShimmer(context, width: 24, height: 24),
                    const SizedBox(width: 16),
                    _buildShimmer(context, width: 24, height: 24),
                    const Spacer(),
                    _buildShimmer(context, width: 24, height: 24),
                  ],
                ),
              ),

              // Likes count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildShimmer(context, width: 80, height: 12),
              ),

              const SizedBox(height: 8),

              // Caption
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShimmer(context, width: double.infinity, height: 12),
                    const SizedBox(height: 6),
                    _buildShimmer(context, width: 200, height: 12),
                  ],
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmer(
    BuildContext context, {
    required double width,
    required double height,
    double borderRadius = 4,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [context.background, context.cardAlt, context.background],
            stops: [
              _animation.value - 0.3,
              _animation.value,
              _animation.value + 0.3,
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays multiple skeleton loaders
class PostSkeletonList extends StatelessWidget {
  const PostSkeletonList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (index) => PostSkeleton(key: ValueKey('skeleton_$index')),
      ),
    );
  }
}
