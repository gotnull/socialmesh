// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/tapback.dart';

void main() {
  group('TapbackType', () {
    test('has all expected values', () {
      expect(TapbackType.values.length, 8);
      expect(TapbackType.values, contains(TapbackType.like));
      expect(TapbackType.values, contains(TapbackType.dislike));
      expect(TapbackType.values, contains(TapbackType.heart));
      expect(TapbackType.values, contains(TapbackType.laugh));
      expect(TapbackType.values, contains(TapbackType.exclamation));
      expect(TapbackType.values, contains(TapbackType.question));
      expect(TapbackType.values, contains(TapbackType.poop));
      expect(TapbackType.values, contains(TapbackType.wave));
    });

    test('like has correct emoji', () {
      expect(TapbackType.like.emoji, '👍');
    });

    test('dislike has correct emoji', () {
      expect(TapbackType.dislike.emoji, '👎');
    });

    test('heart has correct emoji', () {
      expect(TapbackType.heart.emoji, '❤️');
    });

    test('laugh has correct emoji', () {
      expect(TapbackType.laugh.emoji, '😂');
    });

    test('exclamation has correct emoji', () {
      expect(TapbackType.exclamation.emoji, '‼️');
    });

    test('question has correct emoji', () {
      expect(TapbackType.question.emoji, '❓');
    });

    test('poop has correct emoji', () {
      expect(TapbackType.poop.emoji, '💩');
    });

    test('wave has correct emoji', () {
      expect(TapbackType.wave.emoji, '👋');
    });

    test('fromEmoji returns correct type', () {
      expect(TapbackType.fromEmoji('👍'), TapbackType.like);
      expect(TapbackType.fromEmoji('👎'), TapbackType.dislike);
      expect(TapbackType.fromEmoji('❤️'), TapbackType.heart);
      expect(TapbackType.fromEmoji('😂'), TapbackType.laugh);
      expect(TapbackType.fromEmoji('‼️'), TapbackType.exclamation);
      expect(TapbackType.fromEmoji('❓'), TapbackType.question);
      expect(TapbackType.fromEmoji('💩'), TapbackType.poop);
      expect(TapbackType.fromEmoji('👋'), TapbackType.wave);
    });

    test('fromEmoji recognizes aliases as exclamation', () {
      expect(TapbackType.fromEmoji('‼'), TapbackType.exclamation);
      expect(TapbackType.fromEmoji('❗'), TapbackType.exclamation);
    });

    test('fromEmoji returns null for unknown emoji', () {
      expect(TapbackType.fromEmoji('🤔'), isNull);
      expect(TapbackType.fromEmoji(''), isNull);
      expect(TapbackType.fromEmoji('unknown'), isNull);
    });
  });

  group('MessageTapback', () {
    test('creates with required fields', () {
      final tapback = MessageTapback(
        messageId: 'msg-123',
        fromNodeNum: 456,
        emoji: '👍',
      );

      expect(tapback.id, isNotEmpty);
      expect(tapback.messageId, 'msg-123');
      expect(tapback.fromNodeNum, 456);
      expect(tapback.emoji, '👍');
      expect(tapback.timestamp, isNotNull);
    });

    test('creates with all fields', () {
      final timestamp = DateTime(2024, 1, 1);
      final tapback = MessageTapback(
        id: 'tapback-id',
        messageId: 'msg-456',
        fromNodeNum: 789,
        emoji: '❤️',
        timestamp: timestamp,
      );

      expect(tapback.id, 'tapback-id');
      expect(tapback.messageId, 'msg-456');
      expect(tapback.fromNodeNum, 789);
      expect(tapback.emoji, '❤️');
      expect(tapback.timestamp, timestamp);
    });

    test('serializes to JSON', () {
      final tapback = MessageTapback(
        id: 'json-tapback',
        messageId: 'msg-123',
        fromNodeNum: 456,
        emoji: '😂',
      );

      final json = tapback.toJson();

      expect(json['id'], 'json-tapback');
      expect(json['messageId'], 'msg-123');
      expect(json['fromNodeNum'], 456);
      expect(json['emoji'], '😂');
      expect(json['timestamp'], isA<int>());
    });

    test('deserializes from JSON with emoji field', () {
      final json = {
        'id': 'from-json',
        'messageId': 'msg-789',
        'fromNodeNum': 321,
        'emoji': '❤️',
        'timestamp': DateTime(2024, 1, 1).millisecondsSinceEpoch,
      };

      final tapback = MessageTapback.fromJson(json);

      expect(tapback.id, 'from-json');
      expect(tapback.messageId, 'msg-789');
      expect(tapback.fromNodeNum, 321);
      expect(tapback.emoji, '❤️');
    });

    test('deserializes legacy type field to emoji', () {
      final json = {
        'id': 'legacy',
        'messageId': 'msg-123',
        'fromNodeNum': 456,
        'type': 'heart',
      };

      final tapback = MessageTapback.fromJson(json);

      expect(tapback.emoji, '❤️');
    });

    test('deserializes unknown legacy type to default emoji', () {
      final json = {
        'id': 'unknown-type',
        'messageId': 'msg-123',
        'fromNodeNum': 456,
        'type': 'nonexistent',
      };

      final tapback = MessageTapback.fromJson(json);

      expect(tapback.emoji, '👍'); // defaults to thumbs up
    });

    test('roundtrip JSON serialization', () {
      final original = MessageTapback(
        id: 'roundtrip',
        messageId: 'msg-roundtrip',
        fromNodeNum: 999,
        emoji: '👋',
      );

      final json = original.toJson();
      final restored = MessageTapback.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.messageId, original.messageId);
      expect(restored.fromNodeNum, original.fromNodeNum);
      expect(restored.emoji, original.emoji);
    });

    test('stores any arbitrary emoji string', () {
      final tapback = MessageTapback(
        messageId: 'msg-any',
        fromNodeNum: 100,
        emoji: '🦄',
      );

      final json = tapback.toJson();
      final restored = MessageTapback.fromJson(json);

      expect(restored.emoji, '🦄');
    });
  });

  group('MessageThread', () {
    test('creates with required fields', () {
      final thread = MessageThread(parentMessageId: 'parent-123');

      expect(thread.parentMessageId, 'parent-123');
      expect(thread.replyMessageIds, isEmpty);
    });

    test('creates with reply message ids', () {
      final thread = MessageThread(
        parentMessageId: 'parent-456',
        replyMessageIds: ['reply-1', 'reply-2', 'reply-3'],
      );

      expect(thread.parentMessageId, 'parent-456');
      expect(thread.replyMessageIds.length, 3);
      expect(thread.replyMessageIds, contains('reply-1'));
      expect(thread.replyMessageIds, contains('reply-2'));
      expect(thread.replyMessageIds, contains('reply-3'));
    });

    test('copyWith preserves unmodified values', () {
      final original = MessageThread(
        parentMessageId: 'parent-original',
        replyMessageIds: ['reply-1'],
      );

      final copied = original.copyWith(replyMessageIds: ['reply-1', 'reply-2']);

      expect(copied.parentMessageId, 'parent-original');
      expect(copied.replyMessageIds.length, 2);
    });

    test('copyWith can modify parentMessageId', () {
      final original = MessageThread(parentMessageId: 'old-parent');
      final copied = original.copyWith(parentMessageId: 'new-parent');

      expect(copied.parentMessageId, 'new-parent');
    });

    test('serializes to JSON', () {
      final thread = MessageThread(
        parentMessageId: 'json-parent',
        replyMessageIds: ['reply-a', 'reply-b'],
      );

      final json = thread.toJson();

      expect(json['parentMessageId'], 'json-parent');
      expect(json['replyMessageIds'], ['reply-a', 'reply-b']);
    });

    test('deserializes from JSON', () {
      final json = {
        'parentMessageId': 'from-json-parent',
        'replyMessageIds': ['r1', 'r2', 'r3'],
      };

      final thread = MessageThread.fromJson(json);

      expect(thread.parentMessageId, 'from-json-parent');
      expect(thread.replyMessageIds.length, 3);
    });

    test('deserializes with empty list for missing replyMessageIds', () {
      final json = {'parentMessageId': 'minimal'};

      final thread = MessageThread.fromJson(json);

      expect(thread.parentMessageId, 'minimal');
      expect(thread.replyMessageIds, isEmpty);
    });

    test('roundtrip JSON serialization', () {
      final original = MessageThread(
        parentMessageId: 'roundtrip-parent',
        replyMessageIds: ['rt-1', 'rt-2'],
      );

      final json = original.toJson();
      final restored = MessageThread.fromJson(json);

      expect(restored.parentMessageId, original.parentMessageId);
      expect(restored.replyMessageIds, original.replyMessageIds);
    });
  });
}
