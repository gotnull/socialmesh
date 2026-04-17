// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodeboard/models/nodeboard.dart';
import 'package:socialmesh/features/nodeboard/models/nodeboard_enums.dart';

void main() {
  group('BoardStats', () {
    test('fromJson parses correctly', () {
      final stats = BoardStats.fromJson({
        'threadCount': 10,
        'replyCount': 42,
        'sectionCount': 3,
      });
      expect(stats.threadCount, 10);
      expect(stats.replyCount, 42);
      expect(stats.sectionCount, 3);
    });

    test('toJson round-trips', () {
      const stats = BoardStats(threadCount: 5, replyCount: 20, sectionCount: 2);
      final json = stats.toJson();
      final restored = BoardStats.fromJson(json);
      expect(restored, stats);
    });

    test('defaults to zero', () {
      final stats = BoardStats.fromJson({});
      expect(stats.threadCount, 0);
      expect(stats.replyCount, 0);
      expect(stats.sectionCount, 0);
    });

    test('equality', () {
      const a = BoardStats(threadCount: 1, replyCount: 2, sectionCount: 3);
      const b = BoardStats(threadCount: 1, replyCount: 2, sectionCount: 3);
      const c = BoardStats(threadCount: 0, replyCount: 2, sectionCount: 3);
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('NodeBoard', () {
    final sampleJson = {
      'id': 'abc-123',
      'ownerUserId': 'user-1',
      'ownerNodeId': null,
      'slug': 'test-board',
      'title': 'Test Board',
      'sysopName': 'TestSysOp',
      'tagline': 'A test tagline',
      'description': 'A test description',
      'visibility': 'public',
      'themeId': null,
      'welcomeText': 'Welcome!',
      'ansiSplash': null,
      'isListedInNodeDex': true,
      'isGuestPostingAllowed': false,
      'isReadOnly': false,
      'stats': {'threadCount': 5, 'replyCount': 10, 'sectionCount': 3},
      'lastActivityAt': '2026-01-15T12:00:00.000Z',
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-15T12:00:00.000Z',
    };

    test('fromJson parses all fields', () {
      final board = NodeBoard.fromJson(sampleJson);
      expect(board.id, 'abc-123');
      expect(board.ownerUserId, 'user-1');
      expect(board.ownerNodeId, isNull);
      expect(board.slug, 'test-board');
      expect(board.title, 'Test Board');
      expect(board.sysopName, 'TestSysOp');
      expect(board.tagline, 'A test tagline');
      expect(board.visibility, BoardVisibility.public_);
      expect(board.isListedInNodeDex, true);
      expect(board.isGuestPostingAllowed, false);
      expect(board.isReadOnly, false);
      expect(board.stats.threadCount, 5);
      expect(board.lastActivityAt, isNotNull);
    });

    test('toJson round-trips', () {
      final board = NodeBoard.fromJson(sampleJson);
      final json = board.toJson();
      final restored = NodeBoard.fromJson(json);
      expect(restored.id, board.id);
      expect(restored.slug, board.slug);
      expect(restored.title, board.title);
      expect(restored.sysopName, board.sysopName);
      expect(restored.visibility, board.visibility);
    });

    test('copyWith preserves unchanged fields', () {
      final board = NodeBoard.fromJson(sampleJson);
      final updated = board.copyWith(title: 'New Title');
      expect(updated.title, 'New Title');
      expect(updated.slug, board.slug);
      expect(updated.sysopName, board.sysopName);
      expect(updated.id, board.id);
    });

    test('equality by id', () {
      final a = NodeBoard.fromJson(sampleJson);
      final b = NodeBoard.fromJson(sampleJson);
      expect(a, b);
    });
  });

  group('BoardVisibility', () {
    test('fromJson/toJson round-trips', () {
      for (final v in BoardVisibility.values) {
        final json = v.toJson();
        final restored = BoardVisibility.fromJson(json);
        expect(restored, v);
      }
    });

    test('defaults to public for unknown values', () {
      expect(BoardVisibility.fromJson('unknown'), BoardVisibility.public_);
    });
  });
}
