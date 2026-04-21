// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/storage/message_database.dart';

int _seq = 0;
String _uniqueDb() =>
    p.join(Directory.systemTemp.path, 'msg_realack_store_${pid}_${_seq++}.db');

Message _dm({required String id, bool? realAck}) => Message(
  id: id,
  from: 0x11111111,
  to: 0x22222222,
  text: 'hello',
  status: MessageStatus.delivered,
  packetId: null,
  realAck: realAck,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  test('realAck null round-trips as null (legacy / unknown)', () async {
    final storage = MessageDatabase(testDbPath: _uniqueDb());
    await storage.init();
    final msg = _dm(id: 'r1', realAck: null);
    await storage.saveMessage(msg);
    final loaded = (await storage.loadMessages()).firstWhere(
      (m) => m.id == 'r1',
    );
    expect(loaded.realAck, isNull);
    expect(loaded.status, MessageStatus.delivered);
  });

  test('realAck false round-trips as false (implicit mesh ack)', () async {
    final storage = MessageDatabase(testDbPath: _uniqueDb());
    await storage.init();
    final msg = _dm(id: 'r2', realAck: false);
    await storage.saveMessage(msg);
    final loaded = (await storage.loadMessages()).firstWhere(
      (m) => m.id == 'r2',
    );
    expect(loaded.realAck, isFalse);
  });

  test('realAck true round-trips as true (explicit recipient ack)', () async {
    final storage = MessageDatabase(testDbPath: _uniqueDb());
    await storage.init();
    final msg = _dm(id: 'r3', realAck: true);
    await storage.saveMessage(msg);
    final loaded = (await storage.loadMessages()).firstWhere(
      (m) => m.id == 'r3',
    );
    expect(loaded.realAck, isTrue);
  });

  test('migration v9 → v10 adds real_ack column and preserves rows', () async {
    final dbPath = _uniqueDb();

    // Seed a v9 database manually by opening at version 9 and inserting a
    // row without the real_ack column.
    final v9 = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: (db, _) async {
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
        },
      ),
    );
    await v9.insert('messages', {
      'id': 'legacy-1',
      'from_node': 0x11,
      'to_node': 0x22,
      'text': 'pre-migration',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'channel': null,
      'sent': 1,
      'received': 0,
      'acked': 1,
      'status': 'delivered',
      'source': 'unknown',
      'read': 0,
      'conversation_key': 'dm:17:34',
      'is_emoji': 0,
      'retry_count': 0,
      'auto_retry_enabled': 0,
    });
    await v9.close();

    // Now open the same file with the production MessageDatabase — this
    // triggers the v9 → v10 migration.
    final storage = MessageDatabase(testDbPath: dbPath);
    await storage.init();

    final loaded = (await storage.loadMessages()).firstWhere(
      (m) => m.id == 'legacy-1',
    );
    expect(loaded.realAck, isNull, reason: 'legacy row must preserve null');
    expect(loaded.status, MessageStatus.delivered);
    expect(loaded.text, 'pre-migration');
  });
}
