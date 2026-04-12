// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/messaging/conversation_timeline.dart';
import 'package:socialmesh/models/mesh_models.dart';

Message _message({
  required String id,
  required int from,
  required int to,
  required String text,
  required DateTime timestamp,
  int? packetId,
  int? replyId,
  bool isEmoji = false,
  int channel = 0,
}) {
  return Message(
    id: id,
    from: from,
    to: to,
    text: text,
    timestamp: timestamp,
    packetId: packetId,
    replyId: replyId,
    isEmoji: isEmoji,
    channel: channel,
    received: true,
  );
}

void main() {
  group('buildConversationTimelineRows', () {
    test('groups multiple tapbacks under the parent message', () {
      final now = DateTime(2026, 4, 10, 12, 0, 0);
      final parent = _message(
        id: 'parent',
        from: 10,
        to: 20,
        text: 'Hello',
        timestamp: now,
        packetId: 100,
      );
      final tapbackA = _message(
        id: 'tapback-a',
        from: 30,
        to: 20,
        text: '👍',
        timestamp: now.add(const Duration(seconds: 2)),
        packetId: 200,
        replyId: 100,
        isEmoji: true,
      );
      final tapbackB = _message(
        id: 'tapback-b',
        from: 40,
        to: 20,
        text: '😂',
        timestamp: now.add(const Duration(seconds: 3)),
        packetId: 201,
        replyId: 100,
        isEmoji: true,
      );

      final rows = buildConversationTimelineRows([parent, tapbackB, tapbackA]);

      expect(rows, hasLength(1));
      expect(rows.first.message?.id, 'parent');
      expect(rows.first.tapbacks.map((tapback) => tapback.id), [
        'tapback-a',
        'tapback-b',
      ]);
    });

    test('creates an orphan placeholder when the parent is missing', () {
      final now = DateTime(2026, 4, 10, 12, 0, 0);
      final orphanTapback = _message(
        id: 'tapback-orphan',
        from: 30,
        to: 20,
        text: '👋',
        timestamp: now,
        packetId: 200,
        replyId: 999,
        isEmoji: true,
      );

      final rows = buildConversationTimelineRows([orphanTapback]);

      expect(rows, hasLength(1));
      expect(rows.first.isOrphanPlaceholder, isTrue);
      expect(rows.first.orphanReplyId, 999);
      expect(rows.first.tapbacks.single.id, 'tapback-orphan');
    });

    test('groups out-of-order tapbacks once the parent arrives later', () {
      final now = DateTime(2026, 4, 10, 12, 0, 0);
      final tapbackFirst = _message(
        id: 'tapback-first',
        from: 30,
        to: 20,
        text: '❤️',
        timestamp: now,
        packetId: 200,
        replyId: 100,
        isEmoji: true,
      );
      final parentLater = _message(
        id: 'parent-later',
        from: 10,
        to: 20,
        text: 'Parent arrives later',
        timestamp: now.add(const Duration(seconds: 5)),
        packetId: 100,
      );

      final rows = buildConversationTimelineRows([tapbackFirst, parentLater]);

      expect(rows, hasLength(1));
      expect(rows.first.isOrphanPlaceholder, isFalse);
      expect(rows.first.message?.id, 'parent-later');
      expect(rows.first.tapbacks.single.id, 'tapback-first');
    });

    test('keeps standalone emoji messages visible when replyId is missing', () {
      final now = DateTime(2026, 4, 10, 12, 0, 0);
      final standaloneEmoji = _message(
        id: 'standalone-emoji',
        from: 10,
        to: 20,
        text: '👍',
        timestamp: now,
        packetId: 100,
        isEmoji: true,
      );

      final rows = buildConversationTimelineRows([standaloneEmoji]);

      expect(rows, hasLength(1));
      expect(rows.first.message?.id, 'standalone-emoji');
      expect(rows.first.tapbacks, isEmpty);
    });

    test('keeps reply-linked emoji visible when isEmoji is false', () {
      final now = DateTime(2026, 4, 10, 12, 0, 0);
      final legacyEmojiReply = _message(
        id: 'legacy-emoji-reply',
        from: 10,
        to: 20,
        text: '😂',
        timestamp: now,
        packetId: 100,
        replyId: 88,
      );

      final rows = buildConversationTimelineRows([legacyEmojiReply]);

      expect(rows, hasLength(1));
      expect(rows.first.message?.id, 'legacy-emoji-reply');
      expect(rows.first.tapbacks, isEmpty);
    });
  });
}
