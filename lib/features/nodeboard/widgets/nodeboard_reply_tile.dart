// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Reply tile — structurally identical to the Messages inbound bubble
// (see lib/features/messaging/messaging_screen.dart:3292–3396), but
// the left avatar is the node's deterministic SigilWidget glyph (the
// same rendering NodeDex uses), NOT a text-initials circle. Tapping
// the sigil or sender name navigates to the NodeDex detail for the
// author's node. When the reply lacks a node ID (legacy / anonymous
// post) the sigil is seeded from the display-name hash so there's
// always a glyph; tap-through is disabled in that case.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/node_color.dart';
import '../../../core/theme.dart';
import '../../nodedex/screens/nodedex_detail_screen.dart';
import '../../nodedex/widgets/sigil_painter.dart';
import '../models/nodeboard_reply.dart';

class NodeBoardReplyTile extends ConsumerWidget {
  const NodeBoardReplyTile({
    super.key,
    required this.reply,
    this.fallbackNodeId,
    this.showDivider = true,
  });

  final NodeBoardReply reply;

  /// Optional node hex id to use when the reply itself has no
  /// `authorNodeId` (e.g. legacy replies created before the column
  /// existed). Typical source: the board's `ownerNodeId` when the
  /// reply's `authorUserId` matches the board's `ownerUserId`.
  final String? fallbackNodeId;

  final bool showDivider;

  int? get _authorNodeNum =>
      _parseNodeHex(reply.authorNodeId) ?? _parseNodeHex(fallbackNodeId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final realNodeNum = _authorNodeNum;
    // Sigil requires an int — fall back to a hashed display name when
    // we don't have a real node num, so legacy / unlinked posts still
    // render a glyph rather than a placeholder.
    final sigilSeed = realNodeNum ?? reply.authorDisplayName.hashCode.abs();
    final avatarColor = _avatarColorFor(
      context,
      realNodeNum,
      reply.authorDisplayName,
    );
    final tappable = realNodeNum != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing4,
            vertical: AppTheme.spacing12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Deterministic node sigil — tappable when we know the real
              // node num; falls back to a hash-seeded sigil for legacy /
              // unlinked posts so there's always a glyph, never a blank
              // initials circle.
              GestureDetector(
                onTap: tappable
                    ? () => _openNodeDex(context, realNodeNum)
                    : null,
                child: SigilWidget(
                  nodeNum: sigilSeed,
                  size: 32,
                  showBorder: true,
                  borderColor: avatarColor.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(width: AppTheme.spacing10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sender metadata — Wraps so long display names,
                    // node hex IDs, and timestamps never clip.
                    Wrap(
                      spacing: AppTheme.spacing8,
                      runSpacing: AppTheme.spacing2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: tappable
                              ? () => _openNodeDex(context, realNodeNum)
                              : null,
                          child: Text(
                            reply.authorDisplayName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: avatarColor,
                            ),
                          ),
                        ),
                        if (tappable)
                          Text(
                            // lint-allow: hardcoded-string
                            '!${realNodeNum.toRadixString(16).toUpperCase()}',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textTertiary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        Text(
                          _formatTimeAgo(reply.createdAt, l10n),
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing6),
                    Text(
                      reply.body,
                      style: TextStyle(
                        fontSize: 15,
                        color: context.textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            color: context.border.withValues(alpha: 0.15),
          ),
      ],
    );
  }

  void _openNodeDex(BuildContext context, int nodeNum) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NodeDexDetailScreen(nodeNum: nodeNum)),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers — shared with the thread tile (identity rendering is the same).
// ---------------------------------------------------------------------------

int? _parseNodeHex(String? hexId) {
  if (hexId == null || hexId.isEmpty) return null;
  final clean = hexId.startsWith('!') ? hexId.substring(1) : hexId;
  return int.tryParse(clean, radix: 16);
}

Color _avatarColorFor(BuildContext context, int? nodeNum, String fallbackSeed) {
  // Derived the same way as `_MessageBubble._getAvatarColor` in
  // messaging_screen.dart so the same sender looks identical across Messages
  // and NodeBoard replies. Authors without a node number fall back to a stable
  // hash of the author string.
  return nodeColorFromId(nodeNum ?? fallbackSeed.hashCode.abs());
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
