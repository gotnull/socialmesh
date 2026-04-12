// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/notifications/notification_service.dart';

void main() {
  group('MessageReactionTarget', () {
    test('encodes and decodes DM payloads', () {
      const target = MessageReactionTarget(toNodeNum: 123, replyPacketId: 456);

      final payload = target.toPayload();
      final decoded = MessageReactionTarget.fromPayload(payload);

      expect(payload, 'dm:123:456');
      expect(decoded?.toNodeNum, 123);
      expect(decoded?.channelIndex, isNull);
      expect(decoded?.replyPacketId, 456);
    });

    test('encodes and decodes channel payloads', () {
      const target = MessageReactionTarget(
        toNodeNum: 123,
        channelIndex: 7,
        replyPacketId: 456,
      );

      final payload = target.toPayload();
      final decoded = MessageReactionTarget.fromPayload(payload);

      expect(payload, 'channel:7:123:456');
      expect(decoded?.toNodeNum, 123);
      expect(decoded?.channelIndex, 7);
      expect(decoded?.replyPacketId, 456);
    });

    test('rejects payloads without reply packet identity', () {
      expect(MessageReactionTarget.fromPayload('dm:123'), isNull);
      expect(MessageReactionTarget.fromPayload('channel:7:123'), isNull);
    });
  });

  group('PendingMessageNotification.reactionTarget', () {
    test('returns null when reply packet id is absent', () {
      final notification = PendingMessageNotification(
        senderName: 'Alice',
        message: 'Hello',
        fromNodeNum: 123,
      );

      expect(notification.reactionTarget, isNull);
    });

    test(
      'builds a channel reaction target when reply packet id is present',
      () {
        final notification = PendingMessageNotification(
          senderName: 'Alice',
          message: 'Hello',
          fromNodeNum: 123,
          channelIndex: 2,
          replyPacketId: 999,
        );

        expect(notification.reactionTarget?.toPayload(), 'channel:2:123:999');
      },
    );
  });
}
