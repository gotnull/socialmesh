// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Premium board summary card used in the NodeBoard list (My Boards + Discover).
// Matches the NodeDex / Aether card aesthetic: tinted leading icon tile,
// calm typographic hierarchy, bordered surface with subtle accent ring, and a
// wrap-row of stat chips including a visibility pill and time-ago.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../models/nodeboard_enums.dart';
import '../models/nodeboard_summary.dart';
import 'nodeboard_card_container.dart';

class NodeBoardCard extends StatelessWidget {
  const NodeBoardCard({super.key, required this.summary, required this.onTap});

  final NodeBoardSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final radius = BorderRadius.circular(AppTheme.radius16);
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing6,
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: radius,
        border: Border.all(
          color: context.border.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _IconTile(accent: accent),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            summary.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                              letterSpacing: 0.2,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.person_outline,
                                  size: 12,
                                  color: context.textTertiary,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacing4),
                              Expanded(
                                child: Text(
                                  // lint-allow: hardcoded-string
                                  'SysOp: ${summary.sysopName}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: context.textTertiary,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (summary.tagline != null && summary.tagline!.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacing10),
                  Text(
                    summary.tagline!,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textSecondary,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.spacing12),
                Wrap(
                  spacing: AppTheme.spacing8,
                  runSpacing: AppTheme.spacing8,
                  children: [
                    NodeBoardStatChip(
                      icon: Icons.forum_outlined,
                      // lint-allow: hardcoded-string
                      label: '${summary.stats.threadCount} threads',
                    ),
                    NodeBoardStatChip(
                      icon: Icons.mode_comment_outlined,
                      // lint-allow: hardcoded-string
                      label: '${summary.stats.replyCount} replies',
                    ),
                    _VisibilityBadge(visibility: summary.visibility),
                    if (summary.lastActivityAt != null)
                      NodeBoardStatChip(
                        icon: Icons.access_time,
                        label: _timeAgo(summary.lastActivityAt!),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Icon(Icons.dashboard_outlined, size: 22, color: accent),
    );
  }
}

class _VisibilityBadge extends StatelessWidget {
  const _VisibilityBadge({required this.visibility});

  final BoardVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (visibility) {
      // lint-allow: hardcoded-string
      BoardVisibility.public_ => ('PUBLIC', SemanticColors.success),
      // lint-allow: hardcoded-string
      BoardVisibility.unlisted => ('UNLISTED', SemanticColors.warning),
      // lint-allow: hardcoded-string
      BoardVisibility.private_ => ('PRIVATE', context.textTertiary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

String _timeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inDays > 365) {
    // lint-allow: hardcoded-string
    return '${diff.inDays ~/ 365}y ago';
  } else if (diff.inDays > 30) {
    // lint-allow: hardcoded-string
    return '${diff.inDays ~/ 30}mo ago';
  } else if (diff.inDays > 0) {
    // lint-allow: hardcoded-string
    return '${diff.inDays}d ago';
  } else if (diff.inHours > 0) {
    // lint-allow: hardcoded-string
    return '${diff.inHours}h ago';
  } else if (diff.inMinutes > 0) {
    // lint-allow: hardcoded-string
    return '${diff.inMinutes}m ago';
  }
  // lint-allow: hardcoded-string
  return 'just now';
}
