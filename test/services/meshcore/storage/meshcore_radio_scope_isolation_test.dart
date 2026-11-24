// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCore message history follows the connected radio, against real
// scoped database files: what one radio stored is not shown on another and
// comes back on return, and history kept before scoping lands under the
// first MeshCore radio that identifies.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/radio_scope.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_message_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// MeshCore node ids: the first four bytes of each radio's public key.
const int _wisMeshCore = 0x96458be0;
const int _terryDev2 = 0x79426d8d;
const String _peer =
    'aa00000000000000000000000000000000000000000000000000000000000001';

MeshCoreStoredMessage _message(String id, String text) => MeshCoreStoredMessage(
  id: id,
  senderKey: Uint8List.fromList(List.generate(32, (i) => 0xAA - i)),
  text: text,
  timestamp: DateTime(2026, 11, 24, 21, 30),
  isOutgoing: false,
);

void main() {
  late Directory root;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meshcore_scope_');
    SharedPreferences.setMockInitialValues({});
    RadioScope.instance.debugSetRoot(root);
    await RadioScope.instance.init();
    await MeshCoreMessageStore.debugUseRealDatabase();
  });

  tearDown(() async {
    await MeshCoreMessageStore.debugUseInMemory();
    RadioScope.instance.debugSetRoot(null);
    try {
      await root.delete(recursive: true);
    } on FileSystemException {
      // Already gone.
    }
  });

  test('history stored on one radio is not shown on another', () async {
    final store = MeshCoreMessageStore();
    await RadioScope.instance.useNodeNum(_wisMeshCore);
    await store.addContactMessage(_peer, _message('m1', 'via WisMeshCore'));
    expect(await store.loadContactMessages(_peer), hasLength(1));

    await RadioScope.instance.useNodeNum(_terryDev2);
    expect(await store.loadContactMessages(_peer), isEmpty);
    expect(await store.contactKeys(), isEmpty);

    await RadioScope.instance.useNodeNum(_wisMeshCore);
    expect(
      (await store.loadContactMessages(_peer)).single.text,
      'via WisMeshCore',
    );
  });

  test('history kept in preferences lands under the radio that '
      'identifies', () async {
    SharedPreferences.setMockInitialValues({
      'meshcore_messages_contact_$_peer': jsonEncode([
        _message('old', 'from before scoping').toJson(),
      ]),
    });
    await RadioScope.instance.useNodeNum(_wisMeshCore);
    await MeshCoreMessageStore.adoptUnscopedData();
    final store = MeshCoreMessageStore();
    expect(
      (await store.loadContactMessages(_peer)).single.text,
      'from before scoping',
    );

    await RadioScope.instance.useNodeNum(_terryDev2);
    await MeshCoreMessageStore.adoptUnscopedData();
    expect(await store.loadContactMessages(_peer), isEmpty);
  });

  test('a database left at the documents root is merged in and set '
      'aside', () async {
    final flat = p.join(root.path, 'meshcore_messages.db');
    final legacy = await databaseFactoryFfi.openDatabase(flat);
    await legacy.execute(
      'CREATE TABLE meshcore_messages (partition TEXT NOT NULL, '
      'seq INTEGER NOT NULL, body TEXT NOT NULL, '
      'PRIMARY KEY (partition, seq))',
    );
    await legacy.insert('meshcore_messages', {
      'partition': 'c:$_peer',
      'seq': 0,
      'body': jsonEncode(_message('root', 'kept at the root').toJson()),
    });
    await legacy.setVersion(1);
    await legacy.close();

    await RadioScope.instance.useNodeNum(_wisMeshCore);
    await MeshCoreMessageStore.adoptUnscopedData();

    final store = MeshCoreMessageStore();
    expect(
      (await store.loadContactMessages(_peer)).single.text,
      'kept at the root',
    );
    expect(File(flat).existsSync(), isFalse);
    final asideFiles = root.listSync().whereType<File>().where(
      (f) => p.basename(f.path).contains('.adopted-'),
    );
    expect(asideFiles, isNotEmpty);
  });
}
