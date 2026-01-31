// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import '../../../models/mesh_models.dart';
import 'dashboard_widget.dart';
import '../../../core/widgets/loading_indicator.dart';

/// Recent Messages Widget - Shows latest messages from the mesh
class RecentMessagesContent extends ConsumerWidget {
  const RecentMessagesContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(messagesProvider);
    final nodes = ref.watch(nodesProvider);

    // Get last 5 messages, sorted by time
    final recentMessages = messages.toList().reversed.take(5).toList();

    if (recentMessages.isEmpty) {
      return const WidgetEmptyState(
        icon: Icons.chat_bubble_outline,
        message: 'No messages yet',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: recentMessages.length,
      separatorBuilder: (_, i) => Divider(
        height: 1,
        color: context.border.withValues(alpha: 0.5),
        indent: 56,
      ),
      itemBuilder: (context, index) {
        final message = recentMessages[index];
        final sender = nodes[message.from];
        // Use cached sender info from message, with node lookup as enhancement
        final senderName = sender?.displayName ?? message.senderDisplayName;
        final timeAgo = _formatTimeAgo(message.timestamp);

        return _MessageTile(
          senderName: senderName,
          message: message.text,
          timeAgo: timeAgo,
          isBroadcast: message.isBroadcast,
          status: message.status,
        );
      },
    );
  }
}

String _formatTimeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
}

class _MessageTile extends StatelessWidget {
  final String senderName;
  final String message;
  final String timeAgo;
  final bool isBroadcast;
  final MessageStatus status;

  const _MessageTile({
    required this.senderName,
    required this.message,
    required this.timeAgo,
    required this.isBroadcast,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isBroadcast ? Icons.campaign : Icons.person,
              color: context.accentColor,
              size: 18,
            ),
          ),
          SizedBox(width: 10),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Status indicator
          if (status == MessageStatus.pending)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: LoadingIndicator(size: 12),
            )
          else if (status == MessageStatus.failed)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.error_outline,
                size: 14,
                color: AppTheme.errorRed,
              ),
            ),
        ],
      ),
    );
  }
}
