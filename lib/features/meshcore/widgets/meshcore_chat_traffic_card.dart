// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34a — MeshCore chat-traffic diagnostics card.
//
// Surfaces the in-memory `ChatTrafficSnapshot` from the live MeshCore
// session's rate limiter. Used inside the MeshCore Tools screen as a
// glanceable airtime/byte budget readout. Privacy: the card NEVER
// renders message content, pubkeys, channel names, MMFs, or envelope
// bytes. Only counts, byte totals, kind tags, and timestamps.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/meshcore_send_rate_limiter.dart';

class MeshCoreChatTrafficCard extends ConsumerWidget {
  const MeshCoreChatTrafficCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final snapshot = ref.watch(meshCoreChatTrafficProvider);
    final session = ref.watch(meshCoreSessionProvider);
    final hasSession = session != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing4,
      ),
      child: Container(
        key: const ValueKey('meshcore-chat-traffic-card'),
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              title: l10n.meshcoreChatTrafficTitle,
              leadingIcon: Icons.speed_rounded,
            ),
            if (!hasSession)
              _DisconnectedPlaceholder()
            else ...[
              _ProgressBar(
                used: snapshot.currentWindowUsedBytes,
                capacity: snapshot.windowCapacityBytes,
              ),
              const SizedBox(height: AppTheme.spacing12),
              InfoTable(rows: _buildRows(l10n, snapshot)),
            ],
          ],
        ),
      ),
    );
  }

  List<InfoTableRow> _buildRows(AppLocalizations l10n, ChatTrafficSnapshot s) {
    final textBytes = _bytesForKinds(s, [
      MeshCoreSendKind.plainContact,
      MeshCoreSendKind.plainChannel,
    ]);
    final textCount = _countForKinds(s, [
      MeshCoreSendKind.plainContact,
      MeshCoreSendKind.plainChannel,
    ]);
    final replyCount = _countForKinds(s, [
      MeshCoreSendKind.replyContact,
      MeshCoreSendKind.replyChannel,
    ]);
    final reactionCount = _countForKinds(s, [
      MeshCoreSendKind.reactionContact,
      MeshCoreSendKind.reactionChannel,
    ]);
    final rejectedCount = s.rejectedCountByKind.values.fold<int>(
      0,
      (a, b) => a + b,
    );

    // Reply / reaction byte totals are not tracked separately at the
    // window level — D34a tracks only `currentWindowSentBytes` (sum
    // across all kinds) plus per-kind send counts. We reconstruct
    // per-kind bytes by attributing the remainder of sent bytes to
    // replies (reactions stay zero by spec).
    final replyBytes = (s.currentWindowSentBytes - textBytes).clamp(
      0,
      s.windowCapacityBytes,
    );

    return [
      InfoTableRow(
        label: l10n.meshcoreChatTrafficText,
        value: l10n.meshcoreChatTrafficByteCount(textBytes, textCount),
        icon: Icons.chat_bubble_outline_rounded,
      ),
      InfoTableRow(
        label: l10n.meshcoreChatTrafficReplies,
        value: l10n.meshcoreChatTrafficByteCount(replyBytes, replyCount),
        icon: Icons.reply_rounded,
      ),
      InfoTableRow(
        label: l10n.meshcoreChatTrafficReactions,
        value: l10n.meshcoreChatTrafficByteCount(0, reactionCount),
        icon: Icons.emoji_emotions_outlined,
      ),
      InfoTableRow(
        label: l10n.meshcoreChatTrafficRejected,
        value: l10n.meshcoreChatTrafficByteCount(
          s.currentWindowRejectedBytes,
          rejectedCount,
        ),
        icon: Icons.block_rounded,
      ),
      InfoTableRow(
        label: l10n.meshcoreChatTrafficPeak,
        value: l10n.meshcoreChatTrafficBytes(s.peakWindowUsage),
        icon: Icons.trending_up_rounded,
      ),
      InfoTableRow(
        label: l10n.meshcoreChatTrafficLastRejection,
        value: s.lastRejection == null
            ? l10n.meshcoreChatTrafficNone
            : _formatTime(s.lastRejection!),
        icon: Icons.history_rounded,
      ),
      InfoTableRow(
        label: l10n.meshcoreChatTrafficRemaining,
        value: l10n.meshcoreChatTrafficBytes(s.remainingBytes),
        icon: Icons.battery_charging_full_rounded,
      ),
    ];
  }

  static int _bytesForKinds(
    ChatTrafficSnapshot s,
    List<MeshCoreSendKind> kinds,
  ) {
    // Per-kind window bytes are not tracked individually; we only have
    // per-kind send counts. The total `currentWindowSentBytes` is the
    // sum across all kinds. For the "Text" row we need the bytes
    // attributable to plain sends; tests pin this as a derived figure
    // (the difference between the total and reply bytes).
    //
    // Until D34b adds per-kind byte attribution, we surface the count
    // exactly and approximate bytes proportionally by send count when
    // both kinds are populated. When only plain sends exist, the
    // total equals the plain-byte total (exact).
    final totalCount = s.sendCountByKind.values.fold<int>(0, (a, b) => a + b);
    if (totalCount == 0) return 0;
    final myCount = kinds.fold<int>(
      0,
      (a, k) => a + (s.sendCountByKind[k] ?? 0),
    );
    if (myCount == 0) return 0;
    return (s.currentWindowSentBytes * myCount / totalCount).round();
  }

  static int _countForKinds(
    ChatTrafficSnapshot s,
    List<MeshCoreSendKind> kinds,
  ) {
    return kinds.fold<int>(0, (a, k) => a + (s.sendCountByKind[k] ?? 0));
  }

  static String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

class _ProgressBar extends StatelessWidget {
  final int used;
  final int capacity;

  const _ProgressBar({required this.used, required this.capacity});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = context.accentColor;
    final fraction = capacity == 0 ? 0.0 : (used / capacity).clamp(0.0, 1.0);
    final usageColor = fraction >= 0.85
        ? AppTheme.errorRed
        : (fraction >= 0.5 ? AccentColors.orange : accent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                child: LinearProgressIndicator(
                  key: const ValueKey('meshcore-chat-traffic-progress'),
                  value: fraction,
                  minHeight: 8,
                  backgroundColor: context.border,
                  valueColor: AlwaysStoppedAnimation<Color>(usageColor),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Text(
              l10n.meshcoreChatTrafficUsage(used, capacity),
              style: TextStyle(
                color: context.textSecondary,
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DisconnectedPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
      child: Row(
        children: [
          Icon(Icons.link_off_rounded, size: 16, color: context.textTertiary),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              context.l10n.meshcoreChatTrafficNoSession,
              key: const ValueKey('meshcore-chat-traffic-no-session'),
              style: TextStyle(
                color: context.textSecondary,
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
