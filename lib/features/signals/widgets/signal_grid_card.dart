// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/logging.dart';
import '../../nodedex/screens/nodedex_detail_screen.dart';
import '../../nodedex/widgets/sigil_painter.dart';
import '../../../models/social.dart';
import '../../social/widgets/subscribe_button.dart';
import '../../../providers/app_providers.dart';
import '../utils/signal_utils.dart';

/// Compact grid card for signals - used in grid view mode.
///
/// Shows:
/// - Author avatar with overlay
/// - Image preview or content snippet
/// - TTL indicator badge
/// - Proximity indicator
/// - Comment count
/// - Location indicator
/// - Media indicator
class SignalGridCard extends ConsumerWidget {
  const SignalGridCard({super.key, required this.signal, this.onTap});

  final Post signal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    // A signal is mesh-originated if it has a meshNodeId — regardless of
    // whether the sender was also signed in (which sets a non-mesh_ authorId).
    final isMeshSignal = signal.meshNodeId != null;
    final isOwnMeshSignal =
        signal.meshNodeId != null && signal.meshNodeId == myNodeNum;
    final hasImage =
        signal.mediaUrls.isNotEmpty || signal.imageLocalPath != null;
    final hasLocation = signal.location != null;

    AppLogging.signals(
      'SignalGridCard: id=${signal.id}, authorId=${signal.authorId}, isMeshSignal=$isMeshSignal, hasAuthorSnapshot=${signal.authorSnapshot != null}',
    );

    // Get author info
    String authorName = 'Anon';
    String? authorShortName;
    String? avatarUrl;
    Color avatarColor = context.accentColor;

    if (isMeshSignal) {
      // Always resolve from node info when meshNodeId is present — this
      // mirrors what the receiving device shows (Sigil + node long/short name).
      final hexId = signal.meshNodeId!.toRadixString(16).toUpperCase();
      final shortHex = hexId.length >= 4
          ? hexId.substring(hexId.length - 4)
          : hexId;
      final node = nodes[signal.meshNodeId!];
      if (node != null) {
        authorName = node.longName ?? node.shortName ?? '!$hexId';
        authorShortName = node.shortName ?? shortHex;
        if (authorName.length > 12) {
          authorName = '${authorName.substring(0, 11)}...';
        }
        avatarColor = Color((node.hardwareModel?.hashCode ?? 0) | 0xFF000000);
      } else {
        authorName = '!$hexId';
        authorShortName = shortHex;
      }
    } else if (signal.authorSnapshot != null) {
      authorName = signal.authorSnapshot!.displayName;
      if (authorName.length > 12) {
        authorName = '${authorName.substring(0, 11)}...';
      }
      avatarUrl = signal.authorSnapshot!.avatarUrl;
    }

    return BouncyTap(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background - image or content preview (MUST be first)
              if (hasImage)
                _buildImageBackground()
              else
                _buildContentBackground(context),

              // Gradient overlay for readability
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.65),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
                child: const SizedBox.expand(),
              ),

              // Top row badges
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left side: hop count
                      if (signal.hopCount != null)
                        _BadgePill(
                          icon: _getHopIcon(signal.hopCount!),
                          iconColor: getHopCountColor(signal.hopCount!),
                          text: '${signal.hopCount}h',
                        )
                      else
                        const SizedBox.shrink(),
                      // Right side: TTL
                      _TTLBadge(signal: signal),
                    ],
                  ),
                ),
              ),

              // Bottom info area
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Info badges row
                      Row(
                        children: [
                          // Comment count
                          if (signal.commentCount > 0) ...[
                            _IconBadge(
                              icon: Icons.chat_bubble_outline,
                              text: signal.commentCount.toString(),
                            ),
                            const SizedBox(width: 8),
                          ],
                          // Location indicator
                          if (hasLocation) ...[
                            const _IconBadge(
                              icon: Icons.location_on,
                              text: null,
                            ),
                            const SizedBox(width: 8),
                          ],
                          // Image indicator (only show if has image)
                          if (hasImage) ...[
                            const _IconBadge(icon: Icons.image, text: null),
                          ],
                          const Spacer(),
                          // Mesh origin indicator
                          if (isMeshSignal)
                            const _IconBadge(icon: Icons.router, text: null),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Author row
                      Row(
                        children: [
                          if (isMeshSignal)
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => NodeDexDetailScreen(
                                      nodeNum: signal.meshNodeId!,
                                    ),
                                  ),
                                );
                              },
                              child: SigilAvatar(
                                nodeNum: signal.meshNodeId!,
                                size: 22,
                              ),
                            )
                          else
                            UserAvatar(
                              imageUrl: avatarUrl,
                              size: 22,
                              foregroundColor: avatarColor,
                              fallbackIcon: Icons.person,
                            ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        authorName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black87,
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isOwnMeshSignal) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AccentColors.yellow.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                        child: Text(
                                          'you',
                                          style: TextStyle(
                                            color: AccentColors.yellow,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w600,
                                            shadows: const [
                                              Shadow(
                                                color: Colors.black87,
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (isMeshSignal &&
                                    authorShortName != null &&
                                    authorShortName.isNotEmpty)
                                  Text(
                                    authorShortName,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black87,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          // Subscribe button for cloud authors (compact)
                          if ((!isMeshSignal ||
                                  signal.authorSnapshot != null) &&
                              !isOwnMeshSignal) ...[
                            SubscribeButton(
                              authorId:
                                  signal.authorId.startsWith('mesh_') &&
                                      signal.authorSnapshot != null
                                  ? signal.authorId.replaceFirst('mesh_', '')
                                  : signal.authorId,
                              compact: true,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getHopIcon(int hopCount) {
    if (hopCount == 0) return Icons.signal_cellular_4_bar;
    if (hopCount == 1) return Icons.signal_cellular_alt;
    return Icons.signal_cellular_alt_1_bar;
  }

  Widget _buildImageBackground() {
    final hasCloudImage = signal.mediaUrls.isNotEmpty;

    // SizedBox.expand ensures the image takes full space of parent
    if (hasCloudImage) {
      return SizedBox.expand(
        child: Image.network(
          signal.mediaUrls.first,
          fit: BoxFit.cover,
          errorBuilder: (ctx, error, stack) => _buildPlaceholder(ctx),
        ),
      );
    } else if (signal.imageLocalPath != null) {
      return SizedBox.expand(
        child: Image.file(
          File(signal.imageLocalPath!),
          fit: BoxFit.cover,
          errorBuilder: (ctx, error, stack) => _buildPlaceholder(ctx),
        ),
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
          padding: const EdgeInsets.fromLTRB(12, 32, 12, 56),
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

/// Generic icon badge with optional text
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, this.text});

  final IconData icon;
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: Colors.white.withValues(alpha: 0.9),
          shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
        ),
        if (text != null) ...[
          const SizedBox(width: 2),
          Text(
            text!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
            ),
          ),
        ],
      ],
    );
  }
}

/// Badge pill with background for top row
class _BadgePill extends StatelessWidget {
  const _BadgePill({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              color: iconColor,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
        : Colors.black.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
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
