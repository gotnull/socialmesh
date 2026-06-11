// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the two message-identity dedup layers:
// - id-level: re-saving the same Message (stable id) replaces, never
//   duplicates — this is what protects locally-generated messages,
//   whose packet_id is NULL and which therefore never hit the unique
//   packet-identity index;
// - packet-level: two DIFFERENT Message instances carrying the same
//   (packet_id, from) collapse via the unique index, which is what
//   deduplicates reconnect replay across foreground/background ingest.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/storage/message_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _seq = 0;
final _pid = pid;

String _uniqueDbPath() {
  return p.join(Directory.systemTemp.path, 'msg_dedup_${_pid}_${_seq++}.db');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  test('re-saving the same local message (NULL packet_id) replaces by id, '
      'never duplicates', () async {
    final storage = MessageDatabase(testDbPath: _uniqueDbPath());
    await storage.init();

    final local = Message(from: 0x1111, to: 0x2222, text: 'local send');
    expect(local.packetId, isNull);

    await storage.saveMessage(local);
    // Status updates re-save the same logical message.
    await storage.saveMessage(local.copyWith(acked: true));

    final loaded = await storage.loadMessages();
    expect(
      loaded,
      hasLength(1),
      reason:
          'A local message has no packet identity; its stable id is the '
          'dedup key and a re-save must replace, not duplicate.',
    );
    expect(loaded.single.acked, isTrue);
    await storage.close();
  });

  test('two distinct Message instances with the same packet identity '
      'collapse via the unique index', () async {
    final storage = MessageDatabase(testDbPath: _uniqueDbPath());
    await storage.init();

    // Foreground and background ingest paths build deterministic ids
    // from packet identity, but the unique index must hold even if a
    // non-deterministic id reaches the DB.
    final foreground = Message(
      from: 0x3333,
      to: 0x4444,
      text: 'over the air',
      packetId: 777001,
      received: true,
    );
    final background = Message(
      from: 0x3333,
      to: 0x4444,
      text: 'over the air',
      packetId: 777001,
      received: true,
    );
    expect(foreground.id, isNot(background.id));

    await storage.saveMessage(foreground);
    await storage.saveMessage(background);

    final loaded = await storage.loadMessages();
    expect(
      loaded,
      hasLength(1),
      reason:
          'Same (packet_id, from) must collapse to one row regardless of '
          'the Message instance ids.',
    );
    await storage.close();
  });

  test(
    'different local messages with NULL packet_id are NOT deduped',
    () async {
      final storage = MessageDatabase(testDbPath: _uniqueDbPath());
      await storage.init();

      await storage.saveMessage(Message(from: 0x1111, to: 0x2222, text: 'one'));
      await storage.saveMessage(Message(from: 0x1111, to: 0x2222, text: 'two'));

      final loaded = await storage.loadMessages();
      expect(
        loaded,
        hasLength(2),
        reason:
            'NULL packet_id rows are exempt from the packet-identity index '
            'by design: distinct local sends must both persist.',
      );
      await storage.close();
    },
  );
}
