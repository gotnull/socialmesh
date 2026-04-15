// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Post card widget for the mesh feed — displays a single ranked post.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import '../../nodedex/widgets/sigil_painter.dart';
import '../../../services/mesh_feed/mesh_feed_ranking.dart';
import '../../../services/mesh_feed/mesh_post.dart';

/// Displays a single mesh post with provenance, trust, and expiry cues.
class MeshPostCard extends ConsumerWidget {
  const MeshPostCard({super.key, required this.rankedPost});

  /// The ranked post to display.
  final RankedPost rankedPost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final post = rankedPost.post;
    final nodes = ref.watch(nodeIdentityProvider);
    final node = nodes[post.authorNodeNum];
    final longName =
        node?.longName ?? '!${post.authorNodeNum.toRadixString(16)}';
    final shortName = node?.shortName;

    final expiresIn = post.expiresAt.difference(DateTime.now());
    final isExpiringSoon =
        expiresIn.inMinutes < 30 && expiresIn.inMilliseconds > 0;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing6,
      ),
      elevation: 0,
      color: theme.cardColor.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + name + provenance + expiry
            Row(
              children: [
                SigilAvatar(nodeNum: post.authorNodeNum, size: 36),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              longName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (shortName != null && shortName != longName) ...[
                            const SizedBox(width: AppTheme.spacing4),
                            Text(
                              shortName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          _ProvenanceBadge(post: post, l10n: l10n),
                          const SizedBox(width: AppTheme.spacing8),
                          Text(
                            _timeAgo(post.createdAtMs),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isExpiringSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: SemanticColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                    child: Text(
                      l10n.meshFeedExpiresSoon,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: SemanticColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: AppTheme.spacing12),

            // Content
            Text(post.content, style: theme.textTheme.bodyMedium),

            const SizedBox(height: AppTheme.spacing8),

            // Footer: trust indicator + transport metadata
            Row(
              children: [
                _TrustIndicator(
                  score: rankedPost.trustComponent,
                  l10n: l10n,
                  theme: theme,
                ),
                const Spacer(),
                if (post.seenViaTransports.length > 1)
                  Icon(
                    Icons.sync,
                    size: 14,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.4,
                    ),
                  ),
                if (post.hopCount != null) ...[
                  const SizedBox(width: AppTheme.spacing4),
                  Text(
                    '${post.hopCount}h',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(int createdAtMs) {
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(createdAtMs),
    );
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _ProvenanceBadge extends StatelessWidget {
  const _ProvenanceBadge({required this.post, required this.l10n});

  final MeshPost post;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String label;
    Color color;

    if (post.isLocal) {
      label = l10n.meshFeedProvenanceLocal;
      color = AccentColors.green;
    } else if (post.seenViaTransports.contains(MeshTransportType.lanPeerSync) ||
        post.seenViaTransports.contains(MeshTransportType.blePeerSync)) {
      label = l10n.meshFeedProvenanceSynced;
      color = AccentColors.cyan;
    } else if ((post.hopCount ?? 0) <= 1) {
      label = l10n.meshFeedProvenanceNearby;
      color = AccentColors.blue;
    } else {
      label = l10n.meshFeedProvenanceRelayed;
      color = AccentColors.lavender;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: AppTheme.spacing1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _TrustIndicator extends StatelessWidget {
  const _TrustIndicator({
    required this.score,
    required this.l10n,
    required this.theme,
  });

  final double score;
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    if (score >= 0.75) {
      label = l10n.meshFeedTrustEstablished;
      color = AccentColors.green;
    } else if (score >= 0.55) {
      label = l10n.meshFeedTrustTrusted;
      color = AccentColors.cyan;
    } else if (score >= 0.35) {
      label = l10n.meshFeedTrustFamiliar;
      color = AccentColors.blue;
    } else if (score >= 0.15) {
      label = l10n.meshFeedTrustObserved;
      color = AccentColors.lavender;
    } else {
      label = l10n.meshFeedTrustUnknown;
      color = AccentColors.slate;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppTheme.spacing4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
