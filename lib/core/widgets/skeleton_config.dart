// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../theme.dart';

/// Centralized skeleton configuration for consistent loading states.
///
/// Usage:
/// ```dart
/// Skeletonizer(
///   enabled: isLoading,
///   effect: AppSkeletonConfig.effect(context),
///   child: YourWidget(),
/// )
/// ```
class AppSkeletonConfig {
  /// The shimmer effect used across the app
  static ShimmerEffect effect(BuildContext context) => ShimmerEffect(
    baseColor: context.card,
    highlightColor: context.border,
    duration: const Duration(milliseconds: 1500),
  );

  /// Alternative pulse effect for simpler animations
  static PulseEffect pulseEffect(BuildContext context) => PulseEffect(
    from: context.card,
    to: context.border,
    duration: const Duration(milliseconds: 1000),
  );

  /// Standard skeleton config
  static SkeletonizerConfigData config(BuildContext context) =>
      SkeletonizerConfigData(
        effect: effect(context),
        justifyMultiLineText: true,
        textBorderRadius: TextBoneBorderRadius(BorderRadius.circular(4)),
      );

  /// Wrap a widget with skeletonizer using app defaults
  static Widget wrap({
    required BuildContext context,
    required bool enabled,
    required Widget child,
    bool ignoreContainers = false,
    bool ignorePointers = true,
  }) {
    return Skeletonizer(
      enabled: enabled,
      effect: effect(context),
      ignoreContainers: ignoreContainers,
      ignorePointers: ignorePointers,
      child: child,
    );
  }
}

/// A skeleton placeholder for a node card
class SkeletonNodeCard extends StatelessWidget {
  const SkeletonNodeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: [
          // Avatar skeleton
          const Bone.circle(size: 56),
          const SizedBox(width: 16),
          // Content skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone.text(words: 2),
                const SizedBox(height: 8),
                Bone.text(words: 4, fontSize: 12),
                const SizedBox(height: 4),
                Bone.text(words: 3, fontSize: 12),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Chevron
          const Bone.icon(),
        ],
      ),
    );
  }
}

/// A skeleton placeholder for a message/conversation card
class SkeletonConversationCard extends StatelessWidget {
  const SkeletonConversationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: [
          // Avatar skeleton
          const Bone.circle(size: 52),
          const SizedBox(width: 12),
          // Content skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Bone.text(words: 2),
                    Bone.text(words: 1, fontSize: 11),
                  ],
                ),
                const SizedBox(height: 8),
                Bone.text(words: 5, fontSize: 13),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A skeleton placeholder for a channel card
class SkeletonChannelCard extends StatelessWidget {
  const SkeletonChannelCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: [
          // Icon skeleton
          Bone.square(size: 48, borderRadius: BorderRadius.circular(12)),
          const SizedBox(width: 16),
          // Content skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone.text(words: 2),
                const SizedBox(height: 6),
                Bone.text(words: 3, fontSize: 13),
              ],
            ),
          ),
          const Bone.icon(),
        ],
      ),
    );
  }
}

/// A skeleton placeholder for a dashboard widget
class SkeletonDashboardWidget extends StatelessWidget {
  const SkeletonDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Bone.text(words: 2), const Bone.icon(size: 20)],
          ),
          const SizedBox(height: 16),
          // Content lines
          Bone.text(words: 4),
          const SizedBox(height: 8),
          Bone.text(words: 6),
          const SizedBox(height: 8),
          Bone.text(words: 3),
        ],
      ),
    );
  }
}

/// A skeleton placeholder for the NodeDex stats card
class SkeletonNodeDexStatsCard extends StatelessWidget {
  const SkeletonNodeDexStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.border, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Bone.icon(size: 14),
                  const SizedBox(width: 6),
                  Flexible(child: Bone.text(words: 2, fontSize: 12)),
                ],
              ),
            ),
            Flexible(
              flex: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Bone.icon(size: 12),
                  const SizedBox(width: 3),
                  Bone.text(words: 1, fontSize: 12),
                  const SizedBox(width: 8),
                  const Bone.icon(size: 12),
                  const SizedBox(width: 3),
                  Bone.text(words: 1, fontSize: 12),
                  const SizedBox(width: 8),
                  const Bone.icon(size: 12),
                  const SizedBox(width: 3),
                  Bone.text(words: 1, fontSize: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A skeleton placeholder for a NodeDex list tile
class SkeletonNodeDexCard extends StatelessWidget {
  const SkeletonNodeDexCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Sigil avatar placeholder
          const Bone.circle(size: 48),
          const SizedBox(width: 14),
          // Name + metadata
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row
                Row(
                  children: [
                    Flexible(child: Bone.text(words: 2)),
                    const SizedBox(width: 6),
                    Bone.text(words: 1, fontSize: 11),
                  ],
                ),
                const SizedBox(height: 4),
                // Trait + metrics row
                Row(
                  children: [
                    Bone(
                      width: 60,
                      height: 18,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    const Spacer(),
                    const Bone.icon(size: 12),
                    const SizedBox(width: 3),
                    Bone.text(words: 1, fontSize: 11),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Chevron
          const Bone.icon(size: 20),
        ],
      ),
    );
  }
}
