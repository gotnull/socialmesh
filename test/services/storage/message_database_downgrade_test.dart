// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the messages.db migration idempotency contract: after a schema
// downgrade sqflite stamps user_version down while the on-disk schema
// stays at the newest shape, so every onUpgrade block must re-run as a
// no-op. A regression here routes a re-upgrading user into an open
// failure over their entire message history.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/storage/conversation_read_position.dart';
import 'package:socialmesh/services/storage/message_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _seq = 0;
final _pid = pid;

String _uniqueDbPath() {
  return p.join(
    Directory.systemTemp.path,
    'msg_downgrade_${_pid}_${_seq++}.db',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'all migration blocks re-run as no-ops after a version down-stamp',
    () async {
      final dbPath = _uniqueDbPath();
      addTearDown(() {
        final f = File(dbPath);
        if (f.existsSync()) f.deleteSync();
      });

      final storage = MessageDatabase(testDbPath: dbPath);
      await storage.init();
      await storage.saveMessage(
        Message(from: 0x1111, to: 0x2222, text: 'hello', received: true),
      );
      await storage.saveMessage(
        Message(
          from: 0xdeadbeef,
          to: 0xffffffff,
          text: 'broadcast',
          channel: 0,
          received: true,
        ),
      );
      await storage.saveConversationReadPosition(
        ConversationReadPosition(
          conversationKey: 'dm:4369:8738',
          anchorMessageId: 'anchor-1',
          anchorTimestamp: DateTime(2026, 5, 1),
          wasNearLatest: true,
          updatedAt: DateTime(2026, 5, 1),
        ),
      );
      await storage.close();

      // Simulate the post-downgrade state: full v11 schema on disk with the
      // version stamp at 1, so blocks v2 through v11 all re-execute.
      final raw = await databaseFactory.openDatabase(dbPath);
      await raw.execute('PRAGMA user_version = 1');
      await raw.close();

      final reopened = MessageDatabase(testDbPath: dbPath);
      await reopened.init();

      final messages = await reopened.loadMessages();
      expect(messages, hasLength(2));
      expect(messages.map((m) => m.text), containsAll(['hello', 'broadcast']));

      final position = await reopened.loadConversationReadPosition(
        'dm:4369:8738',
      );
      expect(position, isNotNull);
      expect(position!.anchorMessageId, 'anchor-1');
      await reopened.close();
    },
  );

  test('downgrade open retains schema and data for an older binary', () async {
    final dbPath = _uniqueDbPath();
    addTearDown(() {
      final f = File(dbPath);
      if (f.existsSync()) f.deleteSync();
    });

    final storage = MessageDatabase(testDbPath: dbPath);
    await storage.init();
    await storage.saveMessage(
      Message(from: 0x1111, to: 0x2222, text: 'survives', received: true),
    );
    await storage.close();

    // An older binary opens with a lower requested version. The handler
    // retains the schema; only the version stamp moves.
    final older = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(version: 9),
    );
    final rows = await older.query('messages');
    expect(rows, hasLength(1));
    expect(rows.single['text'], 'survives');
    await older.close();

    // Returning to the current binary re-upgrades cleanly.
    final current = MessageDatabase(testDbPath: dbPath);
    await current.init();
    final messages = await current.loadMessages();
    expect(messages.map((m) => m.text), contains('survives'));
    await current.close();
  });
}
