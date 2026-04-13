// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/timeline/adapters/message_timeline_adapter.dart';
import 'package:socialmesh/features/timeline/domain/timeline_item.dart';
import 'package:socialmesh/models/mesh_models.dart';

void main() {
  const myNode = 1000;
  const peerNode = 2000;
  final monday = DateTime(2025, 6, 16); // a Monday

  Message makeMsg({
    required String id,
    required DateTime timestamp,
    int from = myNode,
    int to = peerNode,
    int? channel,
    String text = 'hello',
    bool isEmoji = false,
    int? replyId,
  }) {
    return Message(
      id: id,
      from: from,
      to: to,
      text: text,
      timestamp: timestamp,
      channel: channel,
      isEmoji: isEmoji,
      replyId: replyId,
    );
  }

  group('MessageTimelineAdapter.projectMessages', () {
    test('empty messages returns empty items', () {
      final items = MessageTimelineAdapter.projectMessages(
        messages: [],
        weekStart: monday,
        myNodeNum: myNode,
        nodeNames: const {},
        channelNames: const {},
      );
      expect(items, isEmpty);
    });

    test('messages outside the week are excluded', () {
      final items = MessageTimelineAdapter.projectMessages(
        messages: [
          makeMsg(id: '1', timestamp: monday.subtract(const Duration(days: 1))),
          makeMsg(id: '2', timestamp: monday.add(const Duration(days: 8))),
        ],
        weekStart: monday,
        myNodeNum: myNode,
        nodeNames: const {},
        channelNames: const {},
      );
      expect(items, isEmpty);
    });

    test('tapback reactions are excluded', () {
      final items = MessageTimelineAdapter.projectMessages(
        messages: [
          makeMsg(
            id: '1',
            timestamp: monday.add(const Duration(hours: 10)),
            isEmoji: true,
            replyId: 42,
          ),
        ],
        weekStart: monday,
        myNodeNum: myNode,
        nodeNames: const {},
        channelNames: const {},
      );
      expect(items, isEmpty);
    });

    test('DM messages produce a session item', () {
      final items = MessageTimelineAdapter.projectMessages(
        messages: [
          makeMsg(id: '1', timestamp: monday.add(const Duration(hours: 9))),
          makeMsg(
            id: '2',
            timestamp: monday.add(const Duration(hours: 9, minutes: 5)),
            from: peerNode,
            to: myNode,
          ),
        ],
        weekStart: monday,
        myNodeNum: myNode,
        nodeNames: {peerNode: 'Alice'},
        channelNames: const {},
      );
      expect(items, hasLength(1));
      expect(items.first.title, 'Alice');
      expect(items.first.messageCount, 2);
      expect(items.first.participantIds, [peerNode.toString()]);
      expect(items.first.messageIds, ['1', '2']);
      expect(items.first.trackedDuration, const Duration(minutes: 5));
    });

    test('channel messages produce a session item with channel name', () {
      final items = MessageTimelineAdapter.projectMessages(
        messages: [
          makeMsg(
            id: '1',
            timestamp: monday.add(const Duration(hours: 14)),
            channel: 0,
            to: 0xFFFFFFFF,
          ),
          makeMsg(
            id: '2',
            timestamp: monday.add(const Duration(hours: 14, minutes: 3)),
            from: peerNode,
            to: 0xFFFFFFFF,
            channel: 0,
          ),
        ],
        weekStart: monday,
        myNodeNum: myNode,
        nodeNames: const {},
        channelNames: {0: 'General'},
      );
      expect(items, hasLength(1));
      expect(items.first.title, 'General');
      expect(items.first.messageCount, 2);
    });

    test('gap > 15 min splits into separate sessions', () {
      final items = MessageTimelineAdapter.projectMessages(
        messages: [
          makeMsg(id: '1', timestamp: monday.add(const Duration(hours: 9))),
          makeMsg(
            id: '2',
            timestamp: monday.add(const Duration(hours: 9, minutes: 30)),
          ),
        ],
        weekStart: monday,
        myNodeNum: myNode,
        nodeNames: const {},
        channelNames: const {},
      );
      expect(items, hasLength(2));
    });

    test('directMessages filter excludes channel messages', () {
      final items = MessageTimelineAdapter.projectMessages(
        messages: [
          makeMsg(id: '1', timestamp: monday.add(const Duration(hours: 9))),
          makeMsg(
            id: '2',
            timestamp: monday.add(const Duration(hours: 10)),
            channel: 0,
            to: 0xFFFFFFFF,
          ),
        ],
        weekStart: monday,
        myNodeNum: myNode,
        nodeNames: const {},
        channelNames: const {},
        filter: MessageTimelineFilter.directMessages,
      );
      expect(items, hasLength(1));
      expect(items.first.id, startsWith('dm_'));
    });

    test('channels filter excludes DM messages', () {
      final items = MessageTimelineAdapter.projectMessages(
        messages: [
          makeMsg(id: '1', timestamp: monday.add(const Duration(hours: 9))),
          makeMsg(
            id: '2',
            timestamp: monday.add(const Duration(hours: 10)),
            channel: 1,
            to: 0xFFFFFFFF,
          ),
        ],
        weekStart: monday,
        myNodeNum: myNode,
        nodeNames: const {},
        channelNames: {1: 'Alerts'},
        filter: MessageTimelineFilter.channels,
      );
      expect(items, hasLength(1));
      expect(items.first.id, startsWith('ch_'));
      expect(items.first.title, 'Alerts');
    });

    test('short session gets minimum 30-minute visual duration', () {
      final items = MessageTimelineAdapter.projectMessages(
        messages: [
          makeMsg(id: '1', timestamp: monday.add(const Duration(hours: 12))),
        ],
        weekStart: monday,
        myNodeNum: myNode,
        nodeNames: const {},
        channelNames: const {},
      );
      expect(items, hasLength(1));
      expect(items.first.durationMinutes, greaterThanOrEqualTo(30));
    });

    test('high-volume session gets high priority', () {
      final messages = List.generate(
        25,
        (i) => makeMsg(
          id: 'msg_$i',
          timestamp: monday.add(Duration(hours: 9, minutes: i ~/ 2)),
          from: i.isEven ? myNode : peerNode,
          to: i.isEven ? peerNode : myNode,
        ),
      );
      final items = MessageTimelineAdapter.projectMessages(
        messages: messages,
        weekStart: monday,
        myNodeNum: myNode,
        nodeNames: const {},
        channelNames: const {},
      );
      expect(items, hasLength(1));
      expect(items.first.priority, TimelinePriority.high);
      expect(items.first.messageCount, 25);
    });

    test('medium-volume session gets medium priority', () {
      final messages = List.generate(
        8,
        (i) => makeMsg(
          id: 'msg_$i',
          timestamp: monday.add(Duration(hours: 9, minutes: i)),
        ),
      );
      final items = MessageTimelineAdapter.projectMessages(
        messages: messages,
        weekStart: monday,
        myNodeNum: myNode,
        nodeNames: const {},
        channelNames: const {},
      );
      expect(items, hasLength(1));
      expect(items.first.priority, TimelinePriority.medium);
    });

    test('different conversations produce separate items', () {
      const peer2 = 3000;
      final items = MessageTimelineAdapter.projectMessages(
        messages: [
          makeMsg(
            id: '1',
            timestamp: monday.add(const Duration(hours: 9)),
            to: peerNode,
          ),
          makeMsg(
            id: '2',
            timestamp: monday.add(const Duration(hours: 9, minutes: 2)),
            to: peer2,
          ),
        ],
        weekStart: monday,
        myNodeNum: myNode,
        nodeNames: const {},
        channelNames: const {},
      );
      expect(items, hasLength(2));
    });

    test('unknown peer falls back to hex ID', () {
      final items = MessageTimelineAdapter.projectMessages(
        messages: [
          makeMsg(id: '1', timestamp: monday.add(const Duration(hours: 9))),
        ],
        weekStart: monday,
        myNodeNum: myNode,
        nodeNames: const {},
        channelNames: const {},
      );
      expect(items.first.title, startsWith('!'));
    });

    test('session ID is deterministic', () {
      final messages = [
        makeMsg(id: '1', timestamp: monday.add(const Duration(hours: 11))),
      ];
      final items1 = MessageTimelineAdapter.projectMessages(
        messages: messages,
        weekStart: monday,
        myNodeNum: myNode,
        nodeNames: const {},
        channelNames: const {},
      );
      final items2 = MessageTimelineAdapter.projectMessages(
        messages: messages,
        weekStart: monday,
        myNodeNum: myNode,
        nodeNames: const {},
        channelNames: const {},
      );
      expect(items1.first.id, equals(items2.first.id));
    });
  });
}
