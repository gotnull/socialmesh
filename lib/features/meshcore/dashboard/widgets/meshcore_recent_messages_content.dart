// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../../../providers/meshcore_message_providers.dart';

/// MeshCore-flavoured equivalent of `RecentMessagesContent`. Top 5
/// conversations sorted by most-recent message time, showing name +
/// last-message preview + unread badge + relative timestamp.
class MeshCoreRecentMessagesContent extends ConsumerWidget {
  const MeshCoreRecentMessagesContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final conversationsState = ref.watch(meshCoreConversationsProvider);
    final now = DateTime.now();

    final withMessages =
        conversationsState.conversations
            .where((c) => c.lastMessageTime != null)
            .toList()
          ..sort((a, b) => b.lastMessageTime!.compareTo(a.lastMessageTime!));
    final top = withMessages.take(5).toList();

    if (top.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 32,
              color: context.textTertiary,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              l10n.meshcoreNoMessagesYet,
              style: TextStyle(color: context.textTertiary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: top.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: context.border.withValues(alpha: 0.5),
        indent: 16,
      ),
      itemBuilder: (context, i) {
        final conv = top[i];
        final age = now.difference(conv.lastMessageTime!);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                conv.isChannel ? Icons.forum_rounded : Icons.person_rounded,
                size: 18,
                color: context.textSecondary,
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conv.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _ageLabel(age, context),
                          style: TextStyle(
                            fontSize: 10,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    if (conv.lastMessageText != null &&
                        conv.lastMessageText!.isNotEmpty)
                      Text(
                        conv.lastMessageText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (conv.unreadCount > 0) ...[
                const SizedBox(width: AppTheme.spacing4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing6,
                    vertical: AppTheme.spacing2,
                  ),
                  decoration: BoxDecoration(
                    color: context.accentColor,
                    borderRadius: BorderRadius.circular(AppTheme.radius10),
                  ),
                  child: Text(
                    conv.unreadCount > 99 ? '99+' : '${conv.unreadCount}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _ageLabel(Duration age, BuildContext context) {
    final l10n = context.l10n;
    if (age.inMinutes < 1) return l10n.meshcoreContactJustHeard;
    if (age.inMinutes < 60) {
      return l10n.meshcoreContactHeardMinutesAgo('${age.inMinutes}');
    }
    if (age.inHours < 24) {
      return l10n.meshcoreContactHeardHoursAgo('${age.inHours}');
    }
    return l10n.meshcoreContactHeardDaysAgo('${age.inDays}');
  }
}
