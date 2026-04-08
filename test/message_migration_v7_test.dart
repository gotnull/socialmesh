// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tests for the v6→v7 migration that normalises NULL channel columns
// on broadcast messages to 0, and for the _messageFromRow fallback
// that performs the same normalisation at load time.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:socialmesh/services/storage/message_database.dart';

int _testDbSeq = 0;
final _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'msg_v7_migration_${_testPid}_${_testDbSeq++}.db');
}

/// Creates a v6 database with the full schema but at version 6,
/// so when MessageDatabase opens it at version 7 the migration fires.
Future<String> _createV6Database(List<Map<String, Object?>> rows) async {
  final path = _uniqueTestDbPath();
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 6,
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

/// Creates a v7 database (via MessageDatabase.init()) with raw rows inserted
/// directly via SQL — bypassing _messageToRow — so we can test _messageFromRow
/// normalisation on load.  The raw rows are inserted AFTER the schema is
/// created but via a separate handle that is opened and closed before
/// MessageDatabase is constructed, avoiding handle conflicts.
Future<String> _createV7DatabaseWithRawRows(
  List<Map<String, Object?>> rows,
) async {
  final path = _uniqueTestDbPath();

  // First, let MessageDatabase create the v7 schema.
  final bootstrap = MessageDatabase(testDbPath: path);
  await bootstrap.init();
  await bootstrap.close();

  // Now open a raw handle and insert the rows directly.
  final rawDb = await databaseFactoryFfi.openDatabase(path);
  for (final row in rows) {
    await rawDb.insert('messages', row);
  }
  await rawDb.close();

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

/// Opens the database directly to inspect raw column values without
/// _messageFromRow normalisation.  The caller MUST ensure that any
/// MessageDatabase handle on the same path has been closed first.
Future<List<Map<String, Object?>>> _rawQuery(String dbPath) async {
  final db = await databaseFactoryFfi.openDatabase(dbPath);
  final rows = await db.query('messages', orderBy: 'id ASC');
  await db.close();
  return rows;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  // ---------------------------------------------------------------------------
  // v7 migration — channel column normalisation
  // ---------------------------------------------------------------------------

  group('v7 migration — channel column normalisation', () {
    test('broadcast with NULL channel is normalised to 0', () async {
      final dbPath = await _createV6Database([
        _row(
          id: 'bcast-null-ch',
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Broadcast null channel',
          channel: null,
          conversationKey: 'channel:0',
        ),
      ]);

      // Open via MessageDatabase — triggers v6→v7 migration.
      final storage = MessageDatabase(testDbPath: dbPath);
      await storage.init();

      // Verify via the loaded Message object first (while handle is open).
      final messages = await storage.loadMessages();
      expect(messages.length, 1);
      expect(messages.first.channel, 0);

      // Close before raw inspection to avoid handle conflicts.
      await storage.close();

      // Inspect the raw DB column to confirm the migration wrote channel = 0.
      final rawRows = await _rawQuery(dbPath);
      expect(rawRows.length, 1);
      expect(rawRows.first['channel'], 0);
    });

    test('broadcast with explicit channel 0 is unchanged', () async {
      final dbPath = await _createV6Database([
        _row(
          id: 'bcast-ch0',
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Broadcast channel 0',
          channel: 0,
          conversationKey: 'channel:0',
        ),
      ]);

      final storage = MessageDatabase(testDbPath: dbPath);
      await storage.init();

      final messages = await storage.loadMessages();
      expect(messages.length, 1);
      expect(messages.first.channel, 0);

      await storage.close();

      final rawRows = await _rawQuery(dbPath);
      expect(rawRows.length, 1);
      expect(rawRows.first['channel'], 0);
    });

    test('broadcast with channel 2 is unchanged', () async {
      final dbPath = await _createV6Database([
        _row(
          id: 'bcast-ch2',
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Broadcast channel 2',
          channel: 2,
          conversationKey: 'channel:2',
        ),
      ]);

      final storage = MessageDatabase(testDbPath: dbPath);
      await storage.init();

      final messages = await storage.loadMessages();
      expect(messages.length, 1);
      expect(messages.first.channel, 2);

      await storage.close();

      final rawRows = await _rawQuery(dbPath);
      expect(rawRows.length, 1);
      expect(rawRows.first['channel'], 2);
    });

    test('DM with NULL channel is unchanged', () async {
      final dbPath = await _createV6Database([
        _row(
          id: 'dm-null-ch',
          from: 10,
          to: 12345,
          text: 'DM null channel',
          channel: null,
          conversationKey: 'dm:10:12345',
        ),
      ]);

      final storage = MessageDatabase(testDbPath: dbPath);
      await storage.init();

      // The migration only touches broadcast rows (to_node == 0xFFFFFFFF).
      // DM rows must remain NULL in the raw column.
      await storage.close();

      final rawRows = await _rawQuery(dbPath);
      expect(rawRows.length, 1);
      expect(rawRows.first['channel'], isNull);
    });

    test('migration is idempotent', () async {
      final dbPath = await _createV6Database([
        _row(
          id: 'idem-null',
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Idempotent test',
          channel: null,
          conversationKey: 'channel:0',
        ),
      ]);

      // First open: triggers v6→v7 migration.
      final storage1 = MessageDatabase(testDbPath: dbPath);
      await storage1.init();

      final msgs1 = await storage1.loadMessages();
      expect(msgs1.length, 1);
      expect(msgs1.first.channel, 0);

      // Close (simulate app restart). DB is already at v7.
      await storage1.close();

      // Second open: no migration needed, should not error.
      final storage2 = MessageDatabase(testDbPath: dbPath);
      await storage2.init();

      final msgs2 = await storage2.loadMessages();
      expect(msgs2.length, 1);
      expect(msgs2.first.channel, 0);

      await storage2.close();

      // Raw column is still 0.
      final rawRows = await _rawQuery(dbPath);
      expect(rawRows.first['channel'], 0);
    });

    test('mixed rows — only broadcast NULL channels are fixed', () async {
      final dbPath = await _createV6Database([
        // Broadcast with NULL channel → should become 0
        _row(
          id: 'a-bcast-null',
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Broadcast null',
          channel: null,
          conversationKey: 'channel:0',
        ),
        // Broadcast with channel=0 → unchanged
        _row(
          id: 'b-bcast-ch0',
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Broadcast ch0',
          channel: 0,
          conversationKey: 'channel:0',
        ),
        // DM with NULL channel → unchanged (stays NULL)
        _row(
          id: 'c-dm-null',
          from: 10,
          to: 12345,
          text: 'DM null',
          channel: null,
          conversationKey: 'dm:10:12345',
        ),
        // DM with channel=0 → unchanged
        _row(
          id: 'd-dm-ch0',
          from: 10,
          to: 12345,
          text: 'DM ch0',
          channel: 0,
          conversationKey: 'dm:10:12345',
        ),
      ]);

      final storage = MessageDatabase(testDbPath: dbPath);
      await storage.init();
      await storage.close();

      final rawRows = await _rawQuery(dbPath);
      // Rows are ordered by id ASC: a, b, c, d
      expect(rawRows.length, 4);

      // a: broadcast NULL → fixed to 0
      expect(rawRows[0]['id'], 'a-bcast-null');
      expect(rawRows[0]['channel'], 0);

      // b: broadcast 0 → unchanged at 0
      expect(rawRows[1]['id'], 'b-bcast-ch0');
      expect(rawRows[1]['channel'], 0);

      // c: DM NULL → still NULL (not touched by migration)
      expect(rawRows[2]['id'], 'c-dm-null');
      expect(rawRows[2]['channel'], isNull);

      // d: DM 0 → unchanged at 0
      expect(rawRows[3]['id'], 'd-dm-ch0');
      expect(rawRows[3]['channel'], 0);
    });
  });

  // ---------------------------------------------------------------------------
  // _messageFromRow — channel normalisation on load
  // ---------------------------------------------------------------------------

  group('_messageFromRow — channel normalisation on load', () {
    test('broadcast row with NULL channel loads as channel 0', () async {
      final dbPath = await _createV7DatabaseWithRawRows([
        _row(
          id: 'raw-bcast-null',
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Raw broadcast null channel',
          channel: null,
          conversationKey: 'channel:0',
        ),
      ]);

      // Open via MessageDatabase — _messageFromRow should normalise on load.
      final storage = MessageDatabase(testDbPath: dbPath);
      await storage.init();

      final messages = await storage.loadMessages();
      expect(messages.length, 1);
      expect(messages.first.channel, 0);
      expect(messages.first.isBroadcast, isTrue);

      await storage.close();
    });

    test('DM row with NULL channel loads as channel null', () async {
      final dbPath = await _createV7DatabaseWithRawRows([
        _row(
          id: 'raw-dm-null',
          from: 10,
          to: 12345,
          text: 'Raw DM null channel',
          channel: null,
          conversationKey: 'dm:10:12345',
        ),
      ]);

      final storage = MessageDatabase(testDbPath: dbPath);
      await storage.init();

      final messages = await storage.loadMessages();
      expect(messages.length, 1);
      expect(messages.first.channel, isNull);
      expect(messages.first.isBroadcast, isFalse);

      await storage.close();
    });

    test('broadcast row with channel 0 loads as channel 0', () async {
      final dbPath = await _createV7DatabaseWithRawRows([
        _row(
          id: 'raw-bcast-ch0',
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Raw broadcast channel 0',
          channel: 0,
          conversationKey: 'channel:0',
        ),
      ]);

      final storage = MessageDatabase(testDbPath: dbPath);
      await storage.init();

      final messages = await storage.loadMessages();
      expect(messages.length, 1);
      expect(messages.first.channel, 0);
      expect(messages.first.isBroadcast, isTrue);

      await storage.close();
    });

    test(
      'loaded broadcast message appears in Primary Channel UI filter',
      () async {
        final dbPath = await _createV7DatabaseWithRawRows([
          _row(
            id: 'raw-filter-test',
            from: 10,
            to: 0xFFFFFFFF,
            text: 'Should appear in Primary Channel',
            channel: null,
            conversationKey: 'channel:0',
          ),
        ]);

        final storage = MessageDatabase(testDbPath: dbPath);
        await storage.init();

        final messages = await storage.loadMessages();
        expect(messages.length, 1);

        final m = messages.first;
        // Apply the UI filter that MessagingScreen uses for Primary Channel.
        final matchesPrimaryChannel = m.channel == 0 && m.isBroadcast;
        expect(
          matchesPrimaryChannel,
          isTrue,
          reason:
              '_messageFromRow should normalise NULL → 0 for broadcasts '
              'so they pass the UI filter m.channel == 0 && m.isBroadcast',
        );

        await storage.close();
      },
    );
  });
}
