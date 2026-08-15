// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// End-to-end proof of the isolation contract: data written while connected
// to one radio is invisible while connected to another, and comes back on
// return. Runs against real MessageDatabase and NodeStorageService instances
// rather than the scope service alone, because the leak this prevents was in
// the path from store to file, not in the key derivation.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/radio_scope.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/storage/message_database.dart';
import 'package:socialmesh/services/storage/storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const int _radioA = 0xaaaa1111;
const int _radioB = 0xbbbb2222;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('radio_scope_isolation_');
    SharedPreferences.setMockInitialValues({});
    RadioScope.instance.debugSetRoot(root);
    await RadioScope.instance.init();
  });

  tearDown(() async {
    RadioScope.instance.debugSetRoot(null);
    try {
      await root.delete(recursive: true);
    } on FileSystemException {
      // Already gone.
    }
  });

  Message dmFrom(int peer, String text) =>
      Message(from: peer, to: 0x9999, text: text, received: true, channel: 0);

  Future<List<Message>> openAndLoadMessages() async {
    final db = MessageDatabase();
    await db.init();
    addTearDown(db.close);
    return db.loadMessages();
  }

  Future<void> saveMessage(Message message) async {
    final db = MessageDatabase();
    await db.init();
    await db.saveMessage(message);
    await db.close();
  }

  test('messages written on one radio are invisible on another', () async {
    await RadioScope.instance.useNodeNum(_radioA);
    await saveMessage(dmFrom(0x1234, 'seen through radio A'));
    expect(await openAndLoadMessages(), hasLength(1));

    await RadioScope.instance.useNodeNum(_radioB);

    expect(await openAndLoadMessages(), isEmpty);
  });

  test('switching back to a radio restores its messages', () async {
    await RadioScope.instance.useNodeNum(_radioA);
    await saveMessage(dmFrom(0x1234, 'seen through radio A'));

    await RadioScope.instance.useNodeNum(_radioB);
    await saveMessage(dmFrom(0x5678, 'seen through radio B'));

    await RadioScope.instance.useNodeNum(_radioA);
    final restored = await openAndLoadMessages();

    expect(restored, hasLength(1));
    expect(restored.single.text, 'seen through radio A');
  });

  test('each radio keeps its own node cache and favourites', () async {
    await RadioScope.instance.useNodeNum(_radioA);
    final storageA = NodeStorageService();
    await storageA.init();
    await storageA.saveNode(MeshNode(nodeNum: 0x1234, longName: 'Peer A'));
    final favouritesA = DeviceFavoritesService();
    await favouritesA.init();
    await favouritesA.addFavorite(0x1234);

    await RadioScope.instance.useNodeNum(_radioB);
    final storageB = NodeStorageService();
    await storageB.init();
    final favouritesB = DeviceFavoritesService();
    await favouritesB.init();

    expect(await storageB.loadNodes(), isEmpty);
    expect(favouritesB.favorites, isEmpty);

    await RadioScope.instance.useNodeNum(_radioA);
    final storageBack = NodeStorageService();
    await storageBack.init();
    final favouritesBack = DeviceFavoritesService();
    await favouritesBack.init();

    expect((await storageBack.loadNodes()).single.longName, 'Peer A');
    expect(favouritesBack.favorites, {0x1234});
  });

  test(
    'a first connect to an unknown radio keeps what it hears once identified',
    () async {
      await RadioScope.instance.useDevice(
        deviceId: 'ble-new',
        label: 'Meshtastic_2222',
      );
      await saveMessage(dmFrom(0x5678, 'heard before the identity arrived'));

      await RadioScope.instance.useNodeNum(_radioB, deviceId: 'ble-new');

      final promoted = await openAndLoadMessages();
      expect(promoted, hasLength(1));
      expect(promoted.single.text, 'heard before the identity arrived');
      expect(RadioScope.instance.currentKey, radioScopeKeyForNodeNum(_radioB));
    },
  );

  test(
    'upgrading an install keeps its history on the radio it came from',
    () async {
      // Pre-scoping layout: a flat messages.db and the node number of the radio
      // that produced it.
      RadioScope.instance.debugSetRoot(null);
      final legacyDb = MessageDatabase(testDbPath: '${root.path}/messages.db');
      await legacyDb.init();
      await legacyDb.saveMessage(dmFrom(0x1234, 'from before the upgrade'));
      await legacyDb.close();

      SharedPreferences.setMockInitialValues({'last_my_node_num': _radioA});
      RadioScope.instance.debugSetRoot(root);
      await RadioScope.instance.init();

      expect(RadioScope.instance.currentKey, radioScopeKeyForNodeNum(_radioA));
      final migrated = await openAndLoadMessages();
      expect(migrated, hasLength(1));
      expect(migrated.single.text, 'from before the upgrade');

      await RadioScope.instance.useNodeNum(_radioB);
      expect(await openAndLoadMessages(), isEmpty);
    },
  );
}
