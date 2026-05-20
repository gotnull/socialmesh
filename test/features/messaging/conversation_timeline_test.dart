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

  group('buildConversationTimelineRows sort tie-breaker', () {
    test(
      'tied timestamps: inbound packetId beats outbound numeric-string id',
      () {
        // Reproduces the bug shape: user's pink (no packetId yet) and an
        // inbound packet share a millisecond. Old comparator fell back
        // to a.id.compareTo(b.id), which placed '1747654920123' before
        // 'pkt-<hex>-<hex>' (digits < letters) and wedged outbound into
        // the middle of the list. New comparator prefers settled inbound
        // ahead of pending outbound at tied timestamps.
        final tied = DateTime(2026, 5, 20, 12, 2, 0);
        final pendingOutbound = _message(
          id: '1747654920123',
          from: 10,
          to: 0,
          text: 'Hello everyone',
          timestamp: tied,
        );
        final inbound = _message(
          id: 'pkt-4055b618-1abc',
          from: 0x55E0,
          to: 0,
          text: 'Earlier broadcast',
          timestamp: tied,
          packetId: 0xABCD,
        );

        final rows = buildConversationTimelineRows([pendingOutbound, inbound]);

        expect(rows, hasLength(2));
        expect(
          rows.last.message?.id,
          '1747654920123',
          reason:
              'Pending outbound (no packetId) must sort *after* a settled '
              'inbound at the same timestamp — matching user intent that '
              'their freshly-sent message lands at the end of the list',
        );
      },
    );

    test('tied timestamps with both packetIds sort numerically', () {
      final tied = DateTime(2026, 5, 20, 12, 2, 0);
      final earlier = _message(
        id: 'pkt-1-2',
        from: 1,
        to: 0,
        text: 'A',
        timestamp: tied,
        packetId: 200,
      );
      final later = _message(
        id: 'pkt-1-3',
        from: 1,
        to: 0,
        text: 'B',
        timestamp: tied,
        packetId: 300,
      );

      // Pass them in reverse order to ensure the sort places them, not
      // insertion order.
      final rows = buildConversationTimelineRows([later, earlier]);

      expect(rows.map((row) => row.message?.id), ['pkt-1-2', 'pkt-1-3']);
    });

    test('valid chronological ordering is unchanged by the tiebreaker', () {
      // Outbound at T+0, inbound at T+1s, outbound at T+2s. Both
      // outbounds carry digit-string ids, the inbound carries a pkt-
      // id. Pre-fix lex tiebreaker would never fire here because the
      // timestamps are not tied. Post-fix must also preserve this
      // ordering exactly.
      final t0 = DateTime(2026, 5, 20, 12, 2, 0);
      final outboundFirst = _message(
        id: '1747654920000',
        from: 10,
        to: 0,
        text: 'First',
        timestamp: t0,
      );
      final inboundReply = _message(
        id: 'pkt-aa-bb',
        from: 20,
        to: 0,
        text: 'Reply',
        timestamp: t0.add(const Duration(seconds: 1)),
        packetId: 42,
      );
      final outboundSecond = _message(
        id: '1747654922000',
        from: 10,
        to: 0,
        text: 'Second',
        timestamp: t0.add(const Duration(seconds: 2)),
      );

      final rows = buildConversationTimelineRows([
        outboundSecond,
        inboundReply,
        outboundFirst,
      ]);

      expect(rows.map((row) => row.message?.id), [
        '1747654920000',
        'pkt-aa-bb',
        '1747654922000',
      ]);
    });

    test(
      'unknown-time inbound (sentinel timestamp) sorts before a fresh outbound',
      () {
        // Mirrors the chat-decode behaviour: a packet whose rxTime was
        // missing or implausible is stamped with the chronological
        // sentinel (2020-01-01). It must land *above* (older than) the
        // user's outbound message even though both rows were observed
        // around the same wall-clock moment.
        final sentinel = DateTime.fromMillisecondsSinceEpoch(1577836800 * 1000);
        final unknownTimeInbound = _message(
          id: 'pkt-55e0-1abc',
          from: 0x55E0,
          to: 0,
          text: 'broken rxTime broadcast',
          timestamp: sentinel,
          packetId: 7,
        );
        final freshOutbound = _message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          from: 10,
          to: 0,
          text: 'Hello',
          timestamp: DateTime.now(),
        );

        final rows = buildConversationTimelineRows([
          freshOutbound,
          unknownTimeInbound,
        ]);

        expect(rows.first.message?.id, 'pkt-55e0-1abc');
        expect(rows.last.message?.id, freshOutbound.id);
      },
    );
  });
}
