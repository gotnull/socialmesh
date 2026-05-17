// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// "New messages" divider for the Meshtastic chat screen. Mirrors the
// MeshCore equivalent under lib/features/meshcore/widgets/, kept as a
// separate widget to honour the protocol-isolation rule.
//
// Pure presentational widget. The chat screen owns the boundary state
// (`_initialUnreadCount` captured at open time, before `_markAsRead`
// flips the per-message `read` flags) and decides which list index
// gets this divider inserted above it.

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';

/// Pure boundary computation for the "New messages" divider.
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
///     paged in yet).
///   - otherwise -> `messageCount - unreadCount` (the first new
///     message in the loaded window).
int messagingUnreadDividerInsertIndex({
  required int messageCount,
  required int unreadCount,
}) {
  if (unreadCount <= 0) return -1;
  if (messageCount <= 0) return -1;
  final raw = messageCount - unreadCount;
  if (raw < 0) return 0;
  return raw;
}

class MessagingUnreadDivider extends StatelessWidget {
  const MessagingUnreadDivider({super.key});

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
              context.l10n.messagingChatUnreadDividerLabel,
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
