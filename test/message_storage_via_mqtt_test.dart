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
    p.join(Directory.systemTemp.path, 'msg_via_mqtt_store_${pid}_${_seq++}.db');

Message _inbound({required String id, bool? viaMqtt, int? hopCount}) => Message(
  id: id,
  from: 0x11111111,
  to: 0xFFFFFFFF,
  channel: 0,
  text: 'hello',
  received: true,
  viaMqtt: viaMqtt,
  hopCount: hopCount,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  test('viaMqtt null round-trips as null (unknown transport)', () async {
    final storage = MessageDatabase(testDbPath: _uniqueDb());
    await storage.init();
    await storage.saveMessage(_inbound(id: 'v1', viaMqtt: null));
    final loaded = (await storage.loadMessages()).firstWhere(
      (m) => m.id == 'v1',
    );
    expect(loaded.viaMqtt, isNull);
  });

  test('viaMqtt false round-trips as false (RF delivery)', () async {
    final storage = MessageDatabase(testDbPath: _uniqueDb());
    await storage.init();
    await storage.saveMessage(_inbound(id: 'v2', viaMqtt: false, hopCount: 4));
    final loaded = (await storage.loadMessages()).firstWhere(
      (m) => m.id == 'v2',
    );
    expect(loaded.viaMqtt, isFalse);
    expect(loaded.hopCount, 4);
  });

  test('viaMqtt true round-trips as true (MQTT delivery)', () async {
    final storage = MessageDatabase(testDbPath: _uniqueDb());
    await storage.init();
    await storage.saveMessage(_inbound(id: 'v3', viaMqtt: true, hopCount: 1));
    final loaded = (await storage.loadMessages()).firstWhere(
      (m) => m.id == 'v3',
    );
    expect(loaded.viaMqtt, isTrue);
    expect(loaded.hopCount, 1);
  });

  test('viaMqtt survives reload across database reopen', () async {
    final dbPath = _uniqueDb();
    final storage = MessageDatabase(testDbPath: dbPath);
    await storage.init();
    await storage.saveMessage(_inbound(id: 'v4', viaMqtt: false, hopCount: 2));
    await storage.close();

    final reopened = MessageDatabase(testDbPath: dbPath);
    await reopened.init();
    final loaded = (await reopened.loadMessages()).firstWhere(
      (m) => m.id == 'v4',
    );
    expect(loaded.viaMqtt, isFalse);
    expect(loaded.hopCount, 2);
  });

  test('migration v11 -> v12 adds via_mqtt and legacy rows load as '
      'unknown, not RF', () async {
    final dbPath = _uniqueDb();

    // Seed a v11 database manually: the full v11 schema, which has
    // relay_node but no via_mqtt column.
    final v11 = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 11,
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
              real_ack INTEGER,
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
              relay_node INTEGER,
              sent_at INTEGER,
              last_attempt_at INTEGER,
              retry_count INTEGER NOT NULL DEFAULT 0,
              auto_retry_enabled INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
      ),
    );
    await v11.insert('messages', {
      'id': 'legacy-rf-era',
      'from_node': 0x11,
      'to_node': 0xFFFFFFFF,
      'text': 'pre-migration',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'channel': 0,
      'sent': 0,
      'received': 1,
      'acked': 0,
      'status': 'sent',
      'source': 'unknown',
      'read': 0,
      'conversation_key': 'channel:0',
      'is_emoji': 0,
      'hop_count': 4,
      'retry_count': 0,
      'auto_retry_enabled': 0,
    });
    await v11.close();

    // Open with the production MessageDatabase to run the v12 migration.
    final storage = MessageDatabase(testDbPath: dbPath);
    await storage.init();

    final loaded = (await storage.loadMessages()).firstWhere(
      (m) => m.id == 'legacy-rf-era',
    );
    expect(
      loaded.viaMqtt,
      isNull,
      reason: 'historical rows must surface as unknown, never RF',
    );
    expect(loaded.hopCount, 4, reason: 'existing metadata preserved');

    // The migrated database accepts and round-trips the new column.
    await storage.saveMessage(_inbound(id: 'post-mig', viaMqtt: true));
    final saved = (await storage.loadMessages()).firstWhere(
      (m) => m.id == 'post-mig',
    );
    expect(saved.viaMqtt, isTrue);
  });
}
