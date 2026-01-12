import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/social.dart';
import '../../../providers/app_providers.dart';

/// Compact grid card for signals - used in grid view mode.
///
/// Shows:
/// - Author avatar with overlay
/// - Image preview or content snippet
/// - TTL indicator badge
/// - Proximity indicator
class SignalGridCard extends ConsumerWidget {
  const SignalGridCard({super.key, required this.signal, this.onTap});

  final Post signal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);
    final isMeshSignal = signal.authorId.startsWith('mesh_');
    final hasImage =
        signal.mediaUrls.isNotEmpty || signal.imageLocalPath != null;

    // Get author info
    String authorName = 'Anon';
    String? avatarUrl;
    Color avatarColor = context.accentColor;

    if (signal.authorSnapshot != null) {
      authorName = signal.authorSnapshot!.displayName;
      if (authorName.length > 8) authorName = '${authorName.substring(0, 7)}…';
      avatarUrl = signal.authorSnapshot!.avatarUrl;
    } else if (isMeshSignal && signal.meshNodeId != null) {
      final node = nodes[signal.meshNodeId!];
      if (node != null) {
        authorName =
            node.shortName ?? '!${signal.meshNodeId!.toRadixString(16)}';
        avatarColor = Color((node.hardwareModel?.hashCode ?? 0) | 0xFF000000);
      } else {
        authorName = '!${signal.meshNodeId!.toRadixString(16).substring(0, 4)}';
      }
    }

    return BouncyTap(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background - image or content preview
            Positioned.fill(
              child: hasImage
                  ? _buildImageBackground()
                  : _buildContentBackground(context),
            ),

            // Gradient overlay for readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.6),
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
            ),

            // TTL badge (top right)
            Positioned(top: 8, right: 8, child: _TTLBadge(signal: signal)),

            // Hop count badge (top left)
            if (signal.hopCount != null)
              Positioned(
                top: 8,
                left: 8,
                child: _HopBadge(hopCount: signal.hopCount!),
              ),

            // Author info (bottom)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  UserAvatar(
                    imageUrl: avatarUrl,
                    size: 24,
                    foregroundColor: avatarColor,
                    fallbackIcon: isMeshSignal ? Icons.router : Icons.person,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          authorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!hasImage && signal.content.isNotEmpty)
                          Text(
                            signal.content,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 10,
                              shadows: const [
                                Shadow(color: Colors.black54, blurRadius: 4),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageBackground() {
    final hasCloudImage = signal.mediaUrls.isNotEmpty;

    if (hasCloudImage) {
      return Image.network(
        signal.mediaUrls.first,
        fit: BoxFit.cover,
        errorBuilder: (ctx, error, stack) => _buildPlaceholder(ctx),
      );
    } else if (signal.imageLocalPath != null) {
      return Image.file(
        File(signal.imageLocalPath!),
        fit: BoxFit.cover,
        errorBuilder: (ctx, error, stack) => _buildPlaceholder(ctx),
      );
    }
    return _buildPlaceholder(null);
  }

  Widget _buildContentBackground(BuildContext context) {
    // Gradient background for text-only signals
    final accentColor = context.accentColor;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.3),
            accentColor.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            signal.content,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 12,
              height: 1.3,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext? context) {
    return Container(
      color: context?.card ?? Colors.grey[900],
      child: Icon(
        Icons.sensors,
        size: 32,
        color: context?.textTertiary ?? Colors.grey,
      ),
    );
  }
}

/// Compact TTL badge for grid cards
class _TTLBadge extends StatelessWidget {
  const _TTLBadge({required this.signal});

  final Post signal;

  @override
  Widget build(BuildContext context) {
    final remaining = signal.expiresAt?.difference(DateTime.now());
    if (remaining == null) return const SizedBox.shrink();

    final isExpiringSoon = remaining.inMinutes < 5 && !remaining.isNegative;
    final isExpiringVerySoon = remaining.inMinutes < 1 && !remaining.isNegative;

    String text;
    if (remaining.isNegative) {
      text = '0';
    } else if (remaining.inSeconds < 60) {
      text = '${remaining.inSeconds}s';
    } else if (remaining.inMinutes < 60) {
      text = '${remaining.inMinutes}m';
    } else if (remaining.inHours < 24) {
      text = '${remaining.inHours}h';
    } else {
      text = '${remaining.inDays}d';
    }

    final bgColor = isExpiringVerySoon
        ? AppTheme.errorRed.withValues(alpha: 0.9)
        : isExpiringSoon
        ? AppTheme.warningYellow.withValues(alpha: 0.9)
        : Colors.black.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: 10,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 2),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact hop count badge for grid cards
class _HopBadge extends StatelessWidget {
  const _HopBadge({required this.hopCount});

  final int hopCount;

  @override
  Widget build(BuildContext context) {
    // Determine signal strength icon based on hops
    final IconData icon;
    final Color color;

    if (hopCount == 0) {
      icon = Icons.signal_cellular_4_bar;
      color = AccentColors.green;
    } else if (hopCount == 1) {
      icon = Icons.signal_cellular_alt;
      color = AccentColors.cyan;
    } else {
      icon = Icons.signal_cellular_alt_1_bar;
      color = AppTheme.warningYellow;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '${hopCount}h',
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
