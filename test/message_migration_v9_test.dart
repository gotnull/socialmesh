// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:socialmesh/services/storage/conversation_read_position.dart';
import 'package:socialmesh/services/storage/message_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _testDbSeq = 0;
final _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'msg_migration_v9_${_testPid}_${_testDbSeq++}.db');
}

Future<void> _createV8Database(String dbPath) async {
  final database = await openDatabase(
    dbPath,
    version: 8,
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
      await db.execute(
        'CREATE INDEX idx_messages_conversation ON messages (conversation_key, timestamp DESC)',
      );
      await db.execute(
        'CREATE INDEX idx_messages_node ON messages (from_node, to_node, timestamp DESC)',
      );
      await db.execute(
        'CREATE INDEX idx_messages_packet_id ON messages (packet_id)',
      );
      await db.execute(
        'CREATE UNIQUE INDEX idx_messages_packet_identity ON messages (packet_id, from_node) WHERE packet_id IS NOT NULL',
      );
    },
  );

  await database.insert('messages', {
    'id': 'message-001',
    'from_node': 20,
    'to_node': 10,
    'text': 'Before migration',
    'timestamp': DateTime(2026, 4, 11, 12, 0).millisecondsSinceEpoch,
    'channel': null,
    'sent': 0,
    'received': 1,
    'acked': 0,
    'status': 'sent',
    'error_message': null,
    'routing_error': null,
    'packet_id': 1001,
    'source': 'manual',
    'read': 0,
    'sender_long_name': 'Peer Node',
    'sender_short_name': 'PEER',
    'sender_avatar_color': 0xFF3366FF,
    'conversation_key': 'dm:10:20',
    'reply_id': null,
    'is_emoji': 0,
    'hop_count': null,
    'rx_snr': null,
    'rx_rssi': null,
    'sent_at': null,
    'last_attempt_at': null,
    'retry_count': 0,
    'auto_retry_enabled': 0,
  });

  await database.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'v8 message database upgrades to v9 and supports read positions',
    () async {
      final dbPath = _uniqueTestDbPath();
      await _createV8Database(dbPath);

      final storage = MessageDatabase(testDbPath: dbPath);
      await storage.init();

      final messages = await storage.loadMessages();
      expect(messages, hasLength(1));
      expect(messages.single.id, 'message-001');
      expect(messages.single.text, 'Before migration');

      await storage.saveConversationReadPosition(
        ConversationReadPosition(
          conversationKey: 'dm:10:20',
          anchorMessageId: 'message-001',
          anchorTimestamp: DateTime(2026, 4, 11, 12, 0),
          anchorAlignment: 0.82,
          wasNearLatest: false,
          updatedAt: DateTime(2026, 4, 12, 10, 0),
        ),
      );

      final loadedPosition = await storage.loadConversationReadPosition(
        'dm:10:20',
      );
      expect(loadedPosition, isNotNull);
      expect(loadedPosition!.anchorMessageId, 'message-001');
      expect(loadedPosition.anchorAlignment, 0.82);
    },
  );
}
