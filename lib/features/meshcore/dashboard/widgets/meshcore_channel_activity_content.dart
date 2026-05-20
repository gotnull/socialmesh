// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../../../providers/meshcore_message_providers.dart';
import '../../../../providers/meshcore_providers.dart';

/// MeshCore-flavoured equivalent of `ChannelActivityContent`. Shows
/// per-channel recent traffic and last-message time. Channel order
/// mirrors the channels list (firmware slot order). Per-channel
/// message counts come from `meshCoreConversationsProvider`, the same
/// source the Messages container's Channels sub-tab uses.
class MeshCoreChannelActivityContent extends ConsumerWidget {
  const MeshCoreChannelActivityContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final channelsState = ref.watch(meshCoreChannelsProvider);
    final conversationsState = ref.watch(meshCoreConversationsProvider);
    final channels = channelsState.channels;

    if (channels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_tethering_off_rounded,
              size: 32,
              color: context.textTertiary,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              l10n.meshcoreWidgetChannelActivityEmpty,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));

    // Convo entries for channels are keyed by `channel_<index>` per
    // `meshcore_message_providers.dart`. Cross-ref by index when
    // populating per-channel activity counts.
    final convosByChannelId = {
      for (final c in conversationsState.conversations.where(
        (c) => c.isChannel,
      ))
        c.id: c,
    };

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      itemCount: channels.length.clamp(0, 5),
      separatorBuilder: (_, i) => Divider(
        height: 1,
        color: context.border.withValues(alpha: 0.5),
        indent: 56,
      ),
      itemBuilder: (context, index) {
        final channel = channels[index];
        final convo = convosByChannelId['channel_${channel.index}'];
        final lastMsgTime = convo?.lastMessageTime;
        final isRecent = lastMsgTime != null && lastMsgTime.isAfter(oneHourAgo);
        final unread = convo?.unreadCount ?? 0;
        return _ChannelTile(
          name: channel.name,
          slot: channel.index,
          isPrimary: channel.index == 0,
          unreadCount: unread,
          lastActive: lastMsgTime,
          isRecent: isRecent,
        );
      },
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final String name;
  final int slot;
  final bool isPrimary;
  final int unreadCount;
  final DateTime? lastActive;
  final bool isRecent;

  const _ChannelTile({
    required this.name,
    required this.slot,
    required this.isPrimary,
    required this.unreadCount,
    required this.lastActive,
    required this.isRecent,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing10,
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? context.accentColor.withValues(alpha: 0.15)
                      : context.background,
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
                ),
                child: Center(
                  child: Text(
                    '$slot',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isPrimary
                          ? context.accentColor
                          : context.textSecondary,
                    ),
                  ),
                ),
              ),
              if (isRecent)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: context.accentColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.card, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppTheme.spacing10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name.isNotEmpty
                            ? name
                            : l10n.meshcoreWidgetChannelActivityUnnamedChannel(
                                slot,
                              ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        margin: const EdgeInsets.only(left: AppTheme.spacing6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AccentColors.cyan,
                          borderRadius: BorderRadius.circular(AppTheme.radius4),
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  lastActive == null
                      ? l10n.meshcoreWidgetChannelActivityNoActivity
                      : _relativeTime(context, lastActive!),
                  style: TextStyle(
                    fontSize: 11,
                    color: lastActive == null
                        ? context.textTertiary
                        : context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(BuildContext context, DateTime at) {
    final l10n = context.l10n;
    final delta = DateTime.now().difference(at);
    if (delta.inSeconds < 60) return l10n.meshcoreWidgetChannelActivityJustNow;
    if (delta.inMinutes < 60) {
      return l10n.meshcoreWidgetChannelActivityMinutesAgo(delta.inMinutes);
    }
    if (delta.inHours < 24) {
      return l10n.meshcoreWidgetChannelActivityHoursAgo(delta.inHours);
    }
    return l10n.meshcoreWidgetChannelActivityDaysAgo(delta.inDays);
  }
}
