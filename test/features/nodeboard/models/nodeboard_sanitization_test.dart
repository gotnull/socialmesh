// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Ensures unsafe characters coming from the backend can never reach
// Flutter text rendering via NodeBoard models. Every model that exposes
// user-controlled text must sanitize on deserialization.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodeboard/models/nodeboard.dart';
import 'package:socialmesh/features/nodeboard/models/nodeboard_reply.dart';
import 'package:socialmesh/features/nodeboard/models/nodeboard_section.dart';
import 'package:socialmesh/features/nodeboard/models/nodeboard_summary.dart';
import 'package:socialmesh/features/nodeboard/models/nodeboard_thread.dart';

void main() {
  group('NodeBoard sanitization', () {
    test('NodeBoard strips null bytes and control chars from title/sysop', () {
      final board = NodeBoard.fromJson({
        'id': 'abc',
        'ownerUserId': 'user',
        'slug': 'test',
        'title': 'Safe\u0000Title\u0001',
        'sysopName': 'Sy\u0007sOp',
        'tagline': 'Line\u0000with\u001Fnull',
        'description': 'body\u0000',
        'visibility': 'public',
        'welcomeText': 'Welcome\u0000',
        'ansiSplash': 'ASCII\u0000ART',
        'stats': {'threadCount': 0, 'replyCount': 0, 'sectionCount': 0},
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });

      expect(board.title, 'SafeTitle');
      expect(board.sysopName, 'SysOp');
      expect(board.tagline, 'Linewithnull');
      expect(board.description, 'body');
      expect(board.welcomeText, 'Welcome');
      expect(board.ansiSplash, 'ASCIIART');
    });

    test('NodeBoard preserves newlines and tabs in long text', () {
      final board = NodeBoard.fromJson({
        'id': 'abc',
        'ownerUserId': 'user',
        'slug': 'test',
        'title': 'Title',
        'sysopName': 'Op',
        'description': 'line1\nline2\ttab',
        'welcomeText': 'row1\nrow2',
        'ansiSplash': '╔═╗\n║ ║\n╚═╝',
        'visibility': 'public',
        'stats': {'threadCount': 0, 'replyCount': 0, 'sectionCount': 0},
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });

      expect(board.description, 'line1\nline2\ttab');
      expect(board.welcomeText, 'row1\nrow2');
      expect(board.ansiSplash, '╔═╗\n║ ║\n╚═╝');
    });

    test('NodeBoardSummary sanitizes title/sysop/tagline', () {
      final summary = NodeBoardSummary.fromJson({
        'id': 'abc',
        'slug': 'test',
        'title': 'Sa\u0000fe',
        'sysopName': 'Op\u0001',
        'tagline': 'tag\u001Fline',
        'visibility': 'public',
        'stats': {'threadCount': 0, 'replyCount': 0, 'sectionCount': 0},
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

      expect(summary.title, 'Safe');
      expect(summary.sysopName, 'Op');
      expect(summary.tagline, 'tagline');
    });

    test('NodeBoardSummary tagline null stays null', () {
      final summary = NodeBoardSummary.fromJson({
        'id': 'abc',
        'slug': 'test',
        'title': 'Title',
        'sysopName': 'Op',
        'visibility': 'public',
        'stats': {'threadCount': 0, 'replyCount': 0, 'sectionCount': 0},
        'createdAt': '2026-01-01T00:00:00.000Z',
      });
      expect(summary.tagline, isNull);
    });

    test('NodeBoardThread sanitizes title, body, author', () {
      final thread = NodeBoardThread.fromJson({
        'id': 't1',
        'nodeBoardId': 'b1',
        'sectionId': 's1',
        'authorDisplayName': 'Auth\u0000or',
        'title': 'Ti\u0000tle',
        'body': 'bo\u0001dy',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });

      expect(thread.title, 'Title');
      expect(thread.body, 'body');
      expect(thread.authorDisplayName, 'Author');
    });

    test('NodeBoardReply sanitizes body and author', () {
      final reply = NodeBoardReply.fromJson({
        'id': 'r1',
        'threadId': 't1',
        'nodeBoardId': 'b1',
        'sectionId': 's1',
        'authorDisplayName': 'Re\u0000plier',
        'body': 're\u0000ply\u001F body',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });

      expect(reply.authorDisplayName, 'Replier');
      expect(reply.body, 'reply body');
    });

    test('NodeBoardSection sanitizes title and description', () {
      final section = NodeBoardSection.fromJson({
        'id': 's1',
        'nodeBoardId': 'b1',
        'key': 'general',
        'title': 'Gen\u0000eral',
        'description': 'De\u0000sc',
        'visibility': 'public',
        'postingPolicy': 'authenticatedUsers',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });

      expect(section.title, 'General');
      expect(section.description, 'Desc');
    });

    test('NodeBoardSection null description stays null', () {
      final section = NodeBoardSection.fromJson({
        'id': 's1',
        'nodeBoardId': 'b1',
        'key': 'general',
        'title': 'General',
        'visibility': 'public',
        'postingPolicy': 'authenticatedUsers',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });
      expect(section.description, isNull);
    });
  });
}
