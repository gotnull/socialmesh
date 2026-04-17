// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodeboard/models/nodeboard_enums.dart';
import 'package:socialmesh/features/nodeboard/models/nodeboard_thread.dart';

void main() {
  group('NodeBoardThread', () {
    final sampleJson = {
      'id': 'thread-1',
      'nodeBoardId': 'board-1',
      'sectionId': 'section-1',
      'authorUserId': 'user-1',
      'authorDisplayName': 'TestUser',
      'title': 'Test Thread',
      'body': 'Thread body content',
      'bodyFormat': 'plaintext',
      'isPinned': true,
      'isLocked': false,
      'isDeleted': false,
      'replyCount': 5,
      'lastReplyAt': '2026-01-15T12:00:00.000Z',
      'lastReplyUserId': 'user-2',
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-15T12:00:00.000Z',
    };

    test('fromJson parses all fields', () {
      final thread = NodeBoardThread.fromJson(sampleJson);
      expect(thread.id, 'thread-1');
      expect(thread.title, 'Test Thread');
      expect(thread.authorDisplayName, 'TestUser');
      expect(thread.bodyFormat, BodyFormat.plaintext);
      expect(thread.isPinned, true);
      expect(thread.isLocked, false);
      expect(thread.replyCount, 5);
      expect(thread.lastReplyAt, isNotNull);
    });

    test('toJson round-trips', () {
      final thread = NodeBoardThread.fromJson(sampleJson);
      final json = thread.toJson();
      final restored = NodeBoardThread.fromJson(json);
      expect(restored.id, thread.id);
      expect(restored.title, thread.title);
      expect(restored.isPinned, thread.isPinned);
      expect(restored.replyCount, thread.replyCount);
    });

    test('nullable fields default correctly', () {
      final json = {
        'id': 'thread-2',
        'nodeBoardId': 'board-1',
        'sectionId': 'section-1',
        'authorDisplayName': 'Guest',
        'title': 'Guest Thread',
        'body': 'Content',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      };
      final thread = NodeBoardThread.fromJson(json);
      expect(thread.authorUserId, isNull);
      expect(thread.bodyFormat, BodyFormat.plaintext);
      expect(thread.isPinned, false);
      expect(thread.isLocked, false);
      expect(thread.replyCount, 0);
      expect(thread.lastReplyAt, isNull);
    });

    test('equality by id', () {
      final a = NodeBoardThread.fromJson(sampleJson);
      final b = NodeBoardThread.fromJson(sampleJson);
      expect(a, b);
    });
  });
}
