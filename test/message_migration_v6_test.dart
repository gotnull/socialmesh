// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tests for the v5→v6 migration that repairs historically misclassified
// Primary Channel messages stored under DM-style conversation keys.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:socialmesh/services/storage/message_database.dart';

int _testDbSeq = 0;
final _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'msg_migration_${_testPid}_${_testDbSeq++}.db');
}

/// Creates a v5 database with the full schema but at version 5,
/// so when MessageDatabase opens it at version 6 the migration fires.
Future<String> _createV5Database(List<Map<String, Object?>> rows) async {
  final path = _uniqueTestDbPath();
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            from_node INTEGER NOT NULL,
            to_node INTEGER NOT NULL,
            text TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            channel INTEGER,
            sent INTEGER NOT NULL DEFAULT 0,
            received INTEGER NOT NULL DEFAULT 0,
            acked INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'sent',
            error_message TEXT,
            routing_error TEXT,
            packet_id INTEGER,
            source TEXT NOT NULL DEFAULT 'unknown',
            read INTEGER NOT NULL DEFAULT 0,
            sender_long_name TEXT,
            sender_short_name TEXT,
            sender_avatar_color INTEGER,
            conversation_key TEXT NOT NULL,
            reply_id INTEGER,
            is_emoji INTEGER NOT NULL DEFAULT 0,
            hop_count INTEGER,
            rx_snr REAL,
            rx_rssi INTEGER,
            sent_at INTEGER,
            last_attempt_at INTEGER,
            retry_count INTEGER NOT NULL DEFAULT 0,
            auto_retry_enabled INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_messages_conversation
          ON messages (conversation_key, timestamp DESC)
        ''');
        await db.execute('''
          CREATE INDEX idx_messages_node
          ON messages (from_node, to_node, timestamp DESC)
        ''');
        await db.execute('''
          CREATE INDEX idx_messages_packet_id
          ON messages (packet_id)
        ''');
      },
    ),
  );

  for (final row in rows) {
    await db.insert('messages', row);
  }
  await db.close();

  return path;
}

/// Minimal row for a message with the fields the migration cares about.
Map<String, Object?> _row({
  required String id,
  required int from,
  required int to,
  required String text,
  required String conversationKey,
  int? channel,
  int read = 0,
}) {
  return {
    'id': id,
    'from_node': from,
    'to_node': to,
    'text': text,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'channel': channel,
    'sent': 0,
    'received': 1,
    'acked': 0,
    'status': 'sent',
    'source': 'unknown',
    'read': read,
    'conversation_key': conversationKey,
    'is_emoji': 0,
    'retry_count': 0,
    'auto_retry_enabled': 0,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  group('v5→v6 migration: Primary Channel conversation key repair', () {
    test('broadcast on channel 0 with broken DM key is repaired', () async {
      // Simulate the old bug: a broadcast message (to=0xFFFFFFFF) on
      // channel 0 was stored with conversation_key = 'dm:10:4294967295'
      // instead of 'channel:0'.
      final dbPath = await _createV5Database([
        _row(
          id: 'broken-ch0',
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Hello Primary Channel',
          channel: 0,
          conversationKey: 'dm:10:4294967295',
        ),
      ]);

      // Open via MessageDatabase which triggers v5→v6 migration.
      final storage = MessageDatabase(testDbPath: dbPath);
      await storage.init();

      final messages = await storage.loadMessages();
      expect(messages.length, 1);

      // Load by the corrected conversation key.
      final ch0Messages = await storage.loadConversation('channel:0');
      expect(ch0Messages.length, 1);
      expect(ch0Messages.first.text, 'Hello Primary Channel');

      // The old broken key should return nothing.
      final brokenKeyMessages = await storage.loadConversation(
        'dm:10:4294967295',
      );
      expect(brokenKeyMessages, isEmpty);
    });

    test(
      'broadcast on channel 0 with null channel column is repaired',
      () async {
        // Protobuf default: channel field not present → null in DB.
        // to=0xFFFFFFFF still marks it as broadcast.
        final dbPath = await _createV5Database([
          _row(
            id: 'broken-null-ch',
            from: 10,
            to: 0xFFFFFFFF,
            text: 'Null channel broadcast',
            channel: null,
            conversationKey: 'dm:10:4294967295',
          ),
        ]);

        final storage = MessageDatabase(testDbPath: dbPath);
        await storage.init();

        // COALESCE(channel, 0) should produce 'channel:0'.
        final ch0Messages = await storage.loadConversation('channel:0');
        expect(ch0Messages.length, 1);
        expect(ch0Messages.first.text, 'Null channel broadcast');
      },
    );

    test('broadcast on channel 2 with broken DM key is repaired', () async {
      // A non-primary channel broadcast also affected by the same bug.
      final dbPath = await _createV5Database([
        _row(
          id: 'broken-ch2',
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Hello Channel 2',
          channel: 2,
          conversationKey: 'dm:10:4294967295',
        ),
      ]);

      final storage = MessageDatabase(testDbPath: dbPath);
      await storage.init();

      final ch2Messages = await storage.loadConversation('channel:2');
      expect(ch2Messages.length, 1);
      expect(ch2Messages.first.text, 'Hello Channel 2');
    });

    test('valid DM row is NOT modified by migration', () async {
      // A real DM (to != 0xFFFFFFFF) must not be touched.
      final dbPath = await _createV5Database([
        _row(
          id: 'valid-dm',
          from: 10,
          to: 20,
          text: 'Private message',
          channel: null,
          conversationKey: 'dm:10:20',
        ),
      ]);

      final storage = MessageDatabase(testDbPath: dbPath);
      await storage.init();

      final dmMessages = await storage.loadConversation('dm:10:20');
      expect(dmMessages.length, 1);
      expect(dmMessages.first.text, 'Private message');

      // Should not appear in any channel.
      final ch0Messages = await storage.loadConversation('channel:0');
      expect(ch0Messages, isEmpty);
    });

    test('correctly classified channel messages are NOT modified', () async {
      // Messages already under 'channel:0' (e.g. from the fixed code)
      // must remain untouched.
      final dbPath = await _createV5Database([
        _row(
          id: 'already-correct',
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Already correct',
          channel: 0,
          conversationKey: 'channel:0',
        ),
      ]);

      final storage = MessageDatabase(testDbPath: dbPath);
      await storage.init();

      final ch0Messages = await storage.loadConversation('channel:0');
      expect(ch0Messages.length, 1);
      expect(ch0Messages.first.text, 'Already correct');
    });

    test('migration is idempotent — running twice causes no damage', () async {
      final dbPath = await _createV5Database([
        _row(
          id: 'idem-broken',
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Will be fixed',
          channel: 0,
          conversationKey: 'dm:10:4294967295',
        ),
        _row(
          id: 'idem-correct',
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Already correct',
          channel: 0,
          conversationKey: 'channel:0',
        ),
        _row(
          id: 'idem-dm',
          from: 10,
          to: 20,
          text: 'Valid DM',
          channel: null,
          conversationKey: 'dm:10:20',
        ),
      ]);

      // First open: triggers v5→v6 migration.
      final storage1 = MessageDatabase(testDbPath: dbPath);
      await storage1.init();

      var ch0 = await storage1.loadConversation('channel:0');
      expect(ch0.length, 2); // both broken + correct
      var dm = await storage1.loadConversation('dm:10:20');
      expect(dm.length, 1);

      // Close (simulate app restart) — but the DB is already at v6.
      // Re-opening should not re-run migration (oldVersion == newVersion).
      final storage2 = MessageDatabase(testDbPath: dbPath);
      await storage2.init();

      ch0 = await storage2.loadConversation('channel:0');
      expect(ch0.length, 2);
      dm = await storage2.loadConversation('dm:10:20');
      expect(dm.length, 1);
    });

    test('mixed scenario: broken, correct, and DM rows coexist', () async {
      final dbPath = await _createV5Database([
        // Broken: broadcast on channel 0 with DM key
        _row(
          id: 'mix-broken-1',
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Broken ch0 msg 1',
          channel: 0,
          conversationKey: 'dm:10:4294967295',
        ),
        // Broken: broadcast on channel 0, different sender
        _row(
          id: 'mix-broken-2',
          from: 30,
          to: 0xFFFFFFFF,
          text: 'Broken ch0 msg 2',
          channel: 0,
          conversationKey: 'dm:30:4294967295',
        ),
        // Correct: channel 1 already correct
        _row(
          id: 'mix-ch1',
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Channel 1 message',
          channel: 1,
          conversationKey: 'channel:1',
        ),
        // Correct: already-correct channel 0
        _row(
          id: 'mix-correct-ch0',
          from: 20,
          to: 0xFFFFFFFF,
          text: 'Correct ch0 message',
          channel: 0,
          conversationKey: 'channel:0',
        ),
        // Valid DM
        _row(
          id: 'mix-dm',
          from: 10,
          to: 20,
          text: 'DM message',
          channel: null,
          conversationKey: 'dm:10:20',
        ),
        // Unread broken message — read flag preserved
        _row(
          id: 'mix-unread',
          from: 50,
          to: 0xFFFFFFFF,
          text: 'Unread broken message',
          channel: 0,
          conversationKey: 'dm:50:4294967295',
          read: 0,
        ),
      ]);

      final storage = MessageDatabase(testDbPath: dbPath);
      await storage.init();

      // Channel 0: 2 broken (repaired) + 1 already correct + 1 unread = 4
      final ch0 = await storage.loadConversation('channel:0');
      expect(ch0.length, 4);

      // Channel 1: untouched
      final ch1 = await storage.loadConversation('channel:1');
      expect(ch1.length, 1);

      // DM: untouched
      final dm = await storage.loadConversation('dm:10:20');
      expect(dm.length, 1);

      // Old broken keys: gone
      final broken1 = await storage.loadConversation('dm:10:4294967295');
      expect(broken1, isEmpty);
      final broken2 = await storage.loadConversation('dm:30:4294967295');
      expect(broken2, isEmpty);
      final broken3 = await storage.loadConversation('dm:50:4294967295');
      expect(broken3, isEmpty);

      // Verify unread flag preserved on migrated row
      final unreadMsg = ch0.firstWhere((m) => m.id == 'mix-unread');
      expect(unreadMsg.read, isFalse);
    });
  });
}
