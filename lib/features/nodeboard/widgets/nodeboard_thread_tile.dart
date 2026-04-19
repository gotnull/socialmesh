// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Thread row widget for NodeBoard section thread lists.
//
// A dense, scannable row. Leading icon indicates pinned/regular, trailing
// lock icon when locked. Metadata (author · replies · time ago) sits
// under the title in textTertiary with accent-colored author.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../models/nodeboard_thread.dart';

class NodeBoardThreadTile extends StatelessWidget {
  const NodeBoardThreadTile({super.key, required this.thread, this.onTap});

  final NodeBoardThread thread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final leadingIcon = thread.isPinned
        ? Icons.push_pin
        : Icons.chat_bubble_outline;
    final leadingColor = thread.isPinned
        ? context.accentColor
        : context.textTertiary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                AppLogging.nodeBoard('UI: opening thread=${thread.id}');
                onTap!();
              },
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacing2),
                child: Icon(leadingIcon, size: 16, color: leadingColor),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing6),
                    // Metadata row — wraps naturally so long names and
                    // timestamps never clip.
                    Wrap(
                      spacing: AppTheme.spacing8,
                      runSpacing: AppTheme.spacing4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          thread.authorDisplayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.accentColor,
                          ),
                        ),
                        Text(
                          // lint-allow: hardcoded-string
                          '· ${thread.replyCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiary,
                          ),
                        ),
                        Text(
                          _formatTimeAgo(
                            thread.lastReplyAt ?? thread.updatedAt,
                            l10n,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (thread.isLocked) ...[
                const SizedBox(width: AppTheme.spacing8),
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacing2),
                  child: Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTimeAgo(DateTime dt, dynamic l10n) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays > 365) {
    return l10n.nodeboardYearsAgo(diff.inDays ~/ 365) as String;
  }
  if (diff.inDays > 30) {
    return l10n.nodeboardMonthsAgo(diff.inDays ~/ 30) as String;
  }
  if (diff.inDays > 0) {
    return l10n.nodeboardDaysAgo(diff.inDays) as String;
  }
  if (diff.inHours > 0) {
    return l10n.nodeboardHoursAgo(diff.inHours) as String;
  }
  if (diff.inMinutes > 0) {
    return l10n.nodeboardMinutesAgo(diff.inMinutes) as String;
  }
  return l10n.nodeboardJustNow as String;
}
