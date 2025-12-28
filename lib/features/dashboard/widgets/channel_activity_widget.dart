import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import 'dashboard_widget.dart';

/// Channel Activity Widget - Shows active channels and recent traffic
class ChannelActivityContent extends ConsumerWidget {
  const ChannelActivityContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelsProvider);
    final messages = ref.watch(messagesProvider);

    if (channels.isEmpty) {
      return const WidgetEmptyState(
        icon: Icons.wifi_tethering,
        message: 'No channels configured',
      );
    }

    // Count messages per channel in last hour
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));

    final channelActivity = <int, int>{};
    for (final msg in messages) {
      if (msg.timestamp.isAfter(oneHourAgo) && msg.channel != null) {
        channelActivity[msg.channel!] =
            (channelActivity[msg.channel!] ?? 0) + 1;
      }
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: channels.length.clamp(0, 5),
      separatorBuilder: (_, i) => Divider(
        height: 1,
        color: context.border.withValues(alpha: 0.5),
        indent: 56,
      ),
      itemBuilder: (context, index) {
        final channel = channels[index];
        final msgCount = channelActivity[index] ?? 0;

        return _ChannelTile(
          name: channel.name.isNotEmpty ? channel.name : 'Channel $index',
          index: index,
          messageCount: msgCount,
          isPrimary: index == 0,
        );
      },
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final String name;
  final int index;
  final int messageCount;
  final bool isPrimary;

  const _ChannelTile({
    required this.name,
    required this.index,
    required this.messageCount,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Channel indicator with activity dot
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '$index',
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
              // Activity indicator at top-right
              if (messageCount > 0)
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
                      boxShadow: [
                        BoxShadow(
                          color: context.accentColor.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: 10),
          // Channel info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPrimary)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PRIMARY',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: context.accentColor,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  messageCount == 0
                      ? 'No recent activity'
                      : '$messageCount message${messageCount == 1 ? '' : 's'} in last hour',
                  style: TextStyle(
                    fontSize: 11,
                    color: messageCount > 0
                        ? context.textSecondary
                        : context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
