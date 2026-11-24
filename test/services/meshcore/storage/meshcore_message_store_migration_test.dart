// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Builds before the encrypted meshcore_messages.db kept each conversation
// as a JSON list in SharedPreferences. The first open of the database
// moves them across without losing or duplicating a message.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_message_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _terry =
    '79426d8d00000000000000000000000000000000000000000000000000000001';

MeshCoreStoredMessage _message(String id, String text, int minute) =>
    MeshCoreStoredMessage(
      id: id,
      senderKey: Uint8List.fromList(List.generate(32, (i) => 0x79 + i)),
      text: text,
      timestamp: DateTime(2026, 11, 24, 9, minute),
      isOutgoing: false,
      pathLength: 0,
      snrQuarter: 32,
    );

String _legacyList(List<MeshCoreStoredMessage> messages) =>
    jsonEncode([for (final m in messages) m.toJson()]);

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('meshcore_store_');
  });

  tearDown(() async {
    await MeshCoreMessageStore.debugUseInMemory();
    dir.deleteSync(recursive: true);
  });

  Future<void> reopen() => MeshCoreMessageStore.debugUseDatabaseAt(
    '${dir.path}/meshcore_messages.db',
    factory: databaseFactoryFfi,
  );

  test(
    'DMs and channel posts move across intact and leave preferences',
    () async {
      final dms = [
        _message(
          'd1',
          'Morning, reading you loud and clear from Brunswick.',
          1,
        ),
        _message('d2', 'Heading up to Mt Dandenong after lunch 🔋', 2),
      ];
      final posts = [_message('p1', 'Coburg Hill: anyone on this arvo?', 3)];
      SharedPreferences.setMockInitialValues({
        'meshcore_messages_contact_$_terry': _legacyList(dms),
        'meshcore_messages_channel_1': _legacyList(posts),
        'unrelated_setting': true,
      });
      await reopen();

      await MeshCoreMessageStore.adoptUnscopedData();

      final store = MeshCoreMessageStore();
      final loaded = await store.loadContactMessages(_terry);
      expect(loaded.map((m) => m.id), ['d1', 'd2']);
      expect(loaded[1].text, 'Heading up to Mt Dandenong after lunch 🔋');
      expect(loaded[0].snrQuarter, 32);
      expect(await store.loadChannelMessages(1), hasLength(1));
      expect(await store.contactKeys(), [_terry]);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'unrelated_setting'});
    },
  );

  test('a migration cut short is finished without duplicates', () async {
    SharedPreferences.setMockInitialValues({
      'meshcore_messages_contact_$_terry': _legacyList([
        _message('d1', 'first', 1),
      ]),
    });
    await reopen();
    await MeshCoreMessageStore.adoptUnscopedData();
    final store = MeshCoreMessageStore();
    expect(await store.loadContactMessages(_terry), hasLength(1));

    // The app died after the copy but before the key was removed.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'meshcore_messages_contact_$_terry',
      _legacyList([_message('d1', 'first', 1)]),
    );
    await reopen();
    await MeshCoreMessageStore.adoptUnscopedData();

    expect(await store.loadContactMessages(_terry), hasLength(1));
    expect(prefs.containsKey('meshcore_messages_contact_$_terry'), isFalse);
  });

  test('an unreadable legacy blob is kept for the next attempt', () async {
    SharedPreferences.setMockInitialValues({
      'meshcore_messages_contact_$_terry': '{not json',
      'meshcore_messages_channel_2': _legacyList([_message('p', 'ok', 1)]),
    });
    await reopen();
    await MeshCoreMessageStore.adoptUnscopedData();
    final store = MeshCoreMessageStore();

    expect(await store.loadChannelMessages(2), hasLength(1));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('meshcore_messages_contact_$_terry'), isTrue);
    expect(prefs.containsKey('meshcore_messages_channel_2'), isFalse);
  });

  test('messages persist across a reopen of the database file', () async {
    SharedPreferences.setMockInitialValues({});
    await reopen();
    await MeshCoreMessageStore.adoptUnscopedData();
    final store = MeshCoreMessageStore();
    await store.addContactMessage(_terry, _message('d1', 'saved', 5));
    await store.addChannelMessage(3, _message('p1', 'posted', 6));

    await reopen();
    expect((await store.loadContactMessages(_terry)).single.text, 'saved');
    expect((await store.loadChannelMessages(3)).single.text, 'posted');

    await store.clearChannelMessages(3);
    expect(await store.loadChannelMessages(3), isEmpty);
    expect(await store.loadContactMessages(_terry), hasLength(1));
  });
}
