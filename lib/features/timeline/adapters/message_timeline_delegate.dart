// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/logging.dart';
import '../../../core/routing/conversation_routes.dart';
import '../../messaging/messaging_screen.dart';
import '../domain/timeline_interaction.dart';
import '../domain/timeline_item.dart';
import '../message_timeline_detail_screen.dart';

/// Interaction delegate that shows a detail screen when timeline items
/// are tapped, with an action to open the actual conversation.
///
/// Each timeline item ID encodes its conversation key (e.g. `ch_0_...` or
/// `dm_12345_...`), which this delegate parses to determine the correct
/// [ChatScreen] parameters.
class MessageTimelineDelegate extends TimelineInteractionDelegate {
  /// Map of node numbers to display names for DM title resolution.
  final Map<int, String> nodeNames;

  /// Map of channel indices to channel names.
  final Map<int, String> channelNames;

  /// Accent color for the tapped item (set before navigating).
  Color _accentColor = Colors.white;

  MessageTimelineDelegate({
    required this.nodeNames,
    required this.channelNames,
  });

  /// Sets the accent color to use for the next navigation.
  set accentColor(Color color) => _accentColor = color;

  @override
  void onItemTap(BuildContext context, TimelineItem item) {
    AppLogging.messages('[MsgTimeline] Tap: ${item.id} "${item.title}"');
    final parts = item.id.split('_');
    if (parts.isEmpty) {
      AppLogging.messages('[MsgTimeline] Tap: empty ID parts, ignoring');
      return;
    }

    if (parts[0] == 'ch' && parts.length >= 2) {
      final channelIndex = int.tryParse(parts[1]);
      if (channelIndex == null) {
        AppLogging.messages(
          '[MsgTimeline] Tap: bad channel index "${parts[1]}"',
        );
        return;
      }
      final channelName =
          channelNames[channelIndex] ??
          'Channel $channelIndex'; // lint-allow: hardcoded-string
      AppLogging.messages(
        '[MsgTimeline] Showing detail for channel $channelIndex "$channelName"',
      );
      Navigator.of(context).push(
        _route(
          MessageTimelineDetailScreen(
            item: item,
            accentColor: _accentColor,
            onOpenChat: (detailContext) {
              // Pop detail screen, then push ChatScreen from the timeline's
              // navigator using MaterialPageRoute — matching the standard
              // navigation pattern used by the messaging contacts list.
              Navigator.of(detailContext).pop();
              Navigator.of(context).push(
                _platformRoute<void>(
                  builder: (_) => ChatScreen(
                    type: ConversationType.channel,
                    channelIndex: channelIndex,
                    title: channelName,
                  ),
                  routeName: meshtasticChannelRouteName(channelIndex),
                ),
              );
            },
          ),
        ),
      );
    } else if (parts[0] == 'dm' && parts.length >= 2) {
      final nodeNum = int.tryParse(parts[1]);
      if (nodeNum == null) {
        AppLogging.messages('[MsgTimeline] Tap: bad node num "${parts[1]}"');
        return;
      }
      final nodeName =
          nodeNames[nodeNum] ?? '!${nodeNum.toRadixString(16).padLeft(8, '0')}';
      AppLogging.messages(
        '[MsgTimeline] Showing detail for DM $nodeNum "$nodeName"',
      );
      Navigator.of(context).push(
        _route(
          MessageTimelineDetailScreen(
            item: item,
            accentColor: _accentColor,
            onOpenChat: (detailContext) {
              Navigator.of(detailContext).pop();
              Navigator.of(context).push(
                _platformRoute<void>(
                  builder: (_) => ChatScreen(
                    type: ConversationType.directMessage,
                    nodeNum: nodeNum,
                    title: nodeName,
                  ),
                  routeName: meshtasticDmRouteName(nodeNum),
                ),
              );
            },
          ),
        ),
      );
    } else {
      AppLogging.messages('[MsgTimeline] Tap: unknown prefix "${parts[0]}"');
    }
  }

  static Route<T> _route<T>(Widget screen) {
    return _platformRoute<T>(builder: (_) => screen);
  }

  static Route<T> _platformRoute<T>({
    required WidgetBuilder builder,
    String? routeName,
  }) {
    final settings = routeName == null ? null : RouteSettings(name: routeName);
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => CupertinoPageRoute<T>(
        builder: builder,
        settings: settings,
      ),
      _ => MaterialPageRoute<T>(builder: builder, settings: settings),
    };
  }
}
