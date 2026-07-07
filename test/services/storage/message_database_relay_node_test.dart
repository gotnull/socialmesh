// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the messages.db v11 relay_node contract: the column round-trips
// through save/load, sent/legacy rows load as relayNode == null (the UI
// gates the relay row on non-null), and the v10 -> v11 migration adds the
// column to a pre-existing database without disturbing stored rows.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/storage/message_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _seq = 0;
final _pid = pid;

String _uniqueDbPath() {
  return p.join(Directory.systemTemp.path, 'msg_relay_${_pid}_${_seq++}.db');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  test('relayNode round-trips through save/load', () async {
    final dbPath = _uniqueDbPath();
    addTearDown(() {
      final f = File(dbPath);
      if (f.existsSync()) f.deleteSync();
    });

    final storage = MessageDatabase(testDbPath: dbPath);
    await storage.init();

    await storage.saveMessage(
      Message(
        from: 0x1111,
        to: 0x2222,
        text: 'relayed',
        received: true,
        relayNode: 0xC4,
      ),
    );
    await storage.saveMessage(
      Message(from: 0x3333, to: 0x2222, text: 'direct', received: true),
    );
    await storage.close();

    final reopened = MessageDatabase(testDbPath: dbPath);
    await reopened.init();
    final loaded = await reopened.loadMessages();
    expect(loaded, hasLength(2));
    expect(
      loaded.singleWhere((m) => m.text == 'relayed').relayNode,
      0xC4,
      reason: 'relay_node must persist across a database reopen.',
    );
    expect(
      loaded.singleWhere((m) => m.text == 'direct').relayNode,
      isNull,
      reason: 'A message saved without relay info must stay null.',
    );
    await reopened.close();
  });

  test('v10 -> v11 migration adds relay_node and keeps legacy rows', () async {
    final dbPath = _uniqueDbPath();
    addTearDown(() {
      final f = File(dbPath);
      if (f.existsSync()) f.deleteSync();
    });

    final storage = MessageDatabase(testDbPath: dbPath);
    await storage.init();
    await storage.saveMessage(
      Message(from: 0x1111, to: 0x2222, text: 'legacy', received: true),
    );
    await storage.close();

    // Rebuild the exact v10 on-disk state: drop the v11 column and stamp
    // the version back so only the v11 block re-runs on the next open.
    final raw = await databaseFactory.openDatabase(dbPath);
    await raw.execute('ALTER TABLE messages DROP COLUMN relay_node');
    await raw.execute('PRAGMA user_version = 10');
    await raw.close();

    final reopened = MessageDatabase(testDbPath: dbPath);
    await reopened.init();

    final loaded = await reopened.loadMessages();
    expect(loaded, hasLength(1));
    expect(
      loaded.single.relayNode,
      isNull,
      reason: 'A pre-v11 row has no relay info and must load as null.',
    );

    // The migrated column must accept new writes.
    await reopened.saveMessage(
      Message(
        from: 0x5555,
        to: 0x2222,
        text: 'post-migration',
        received: true,
        relayNode: 0x0A,
      ),
    );
    final after = await reopened.loadMessages();
    expect(
      after.singleWhere((m) => m.text == 'post-migration').relayNode,
      0x0A,
    );
    await reopened.close();
  });
}
