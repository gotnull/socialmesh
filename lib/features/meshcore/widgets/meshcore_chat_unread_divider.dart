// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q1: "New messages" divider for the MeshCore chat screen.
//
// Pure presentational widget. The chat screen owns the boundary
// state (`_initialUnreadCount` captured at open time, before the
// per-conversation `clearUnreadCount` fires) and decides which list
// index gets this divider inserted above it.
//
// Layout: a horizontal `Divider` line on either side of a centered
// localized label, tinted with the accent color. Padding mirrors
// the chat-screen's vertical message rhythm.

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';

/// D-Q1: pure boundary computation for the "New messages" divider.
///
/// Returns the message index the divider should sit ABOVE in the
/// loaded chat window, or `-1` when the divider should be suppressed
/// (no unread snapshot, or an empty window).
///
/// Semantics:
///   - `unreadCount <= 0` -> -1 (no divider).
///   - `messageCount == 0` -> -1 (no messages to anchor against).
///   - `unreadCount >= messageCount` -> 0 (clamp to top of window so
///     the divider is still surfaced even when older pages haven't
///     paged in yet via D43).
///   - otherwise -> `messageCount - unreadCount` (the first new
///     message in the loaded window).
int chatUnreadDividerInsertIndex({
  required int messageCount,
  required int unreadCount,
}) {
  if (unreadCount <= 0) return -1;
  if (messageCount <= 0) return -1;
  final raw = messageCount - unreadCount;
  if (raw < 0) return 0;
  return raw;
}

class MeshCoreChatUnreadDivider extends StatelessWidget {
  const MeshCoreChatUnreadDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.accentColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      child: Row(
        children: [
          Expanded(child: Divider(color: color)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing8),
            child: Text(
              context.l10n.meshcoreChatUnreadDividerLabel,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: color)),
        ],
      ),
    );
  }
}
