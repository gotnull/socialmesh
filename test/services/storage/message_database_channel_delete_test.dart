// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/storage/message_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _seq = 0;
final _pid = pid;

String _uniqueDbPath() {
  return p.join(
    Directory.systemTemp.path,
    'msg_channel_delete_${_pid}_${_seq++}.db',
  );
}

Message _broadcast({required int channel, required String text}) {
  return Message(
    from: 0xdeadbeef,
    to: 0xffffffff,
    text: text,
    channel: channel,
    received: true,
  );
}

Message _dm({required int from, required int to, required String text}) {
  return Message(from: from, to: to, text: text, received: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  test('deleteMessagesForChannel removes only messages with matching channel '
      'index and leaves DMs / other channels untouched', () async {
    final storage = MessageDatabase(testDbPath: _uniqueDbPath());
    await storage.init();

    await storage.saveMessage(_broadcast(channel: 0, text: 'primary hi'));
    await storage.saveMessage(_broadcast(channel: 1, text: 'admin alert 1'));
    await storage.saveMessage(_broadcast(channel: 1, text: 'admin alert 2'));
    await storage.saveMessage(_broadcast(channel: 1, text: 'admin alert 3'));
    await storage.saveMessage(_dm(from: 0x1111, to: 0x2222, text: 'hello'));

    final removed = await storage.deleteMessagesForChannel(1);
    expect(removed, 3);

    final remaining = await storage.loadMessages();
    expect(remaining, hasLength(2));
    expect(
      remaining.where((m) => m.channel == 1),
      isEmpty,
      reason: 'channel 1 must be empty after bulk delete',
    );
    expect(
      remaining.where((m) => m.channel == 0).map((m) => m.text),
      contains('primary hi'),
    );
    expect(
      remaining.where((m) => m.channel == null).map((m) => m.text),
      contains('hello'),
      reason: 'DMs (channel == null) must survive bulk delete',
    );
  });

  test('deleteMessagesForChannel returns 0 when no messages match', () async {
    final storage = MessageDatabase(testDbPath: _uniqueDbPath());
    await storage.init();

    await storage.saveMessage(_broadcast(channel: 0, text: 'primary'));

    final removed = await storage.deleteMessagesForChannel(7);
    expect(removed, 0);

    final remaining = await storage.loadMessages();
    expect(remaining, hasLength(1));
  });
}
