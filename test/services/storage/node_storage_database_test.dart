// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The node store keeps one row per node in a radio-scoped database. Older
// builds kept every node as one JSON string in preferences; the first open
// of a scope's database moves that list across without losing or
// duplicating a node.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/radio_scope.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/storage/storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const int _radio = 0x96458be0;

Map<String, dynamic> _legacyNode(int num, String name, {double? lat}) => {
  'nodeNum': num,
  'longName': name,
  'shortName': name.substring(0, 2),
  'latitude': lat,
  'longitude': lat == null ? null : 144.96,
  'lastHeard': DateTime(2026, 11, 25, 9).millisecondsSinceEpoch,
  'firstHeard': DateTime(2026, 11, 1).millisecondsSinceEpoch,
};

void main() {
  late Directory root;
  late String dbPath;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('node_store_');
    dbPath = p.join(root.path, 'nodes.db');
    SharedPreferences.setMockInitialValues({});
    RadioScope.instance.debugSetRoot(root);
    await RadioScope.instance.init();
    await RadioScope.instance.useNodeNum(_radio);
    NodeStorageService.debugUseDatabase(databaseFactoryFfi, () async => dbPath);
  });

  tearDown(() async {
    NodeStorageService.debugUseInMemory();
    RadioScope.instance.debugSetRoot(null);
    try {
      await root.delete(recursive: true);
    } on FileSystemException {
      // Already gone.
    }
  });

  Future<void> seedLegacy(Object value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      RadioScope.instance.prefsKey('nodes'),
      value is String ? value : jsonEncode(value),
    );
  }

  test('nodes kept in preferences move across and the key goes', () async {
    await seedLegacy([
      _legacyNode(1, 'Coburg Hill', lat: -37.74),
      _legacyNode(2, 'Brunswick East'),
    ]);
    final store = NodeStorageService();
    await store.init();

    final nodes = await store.loadNodes();
    expect(nodes.map((n) => n.longName).toSet(), {
      'Coburg Hill',
      'Brunswick East',
    });
    expect(nodes.firstWhere((n) => n.nodeNum == 1).latitude, -37.74);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(RadioScope.instance.prefsKey('nodes')), isFalse);
    await store.close();
  });

  test(
    'a migration cut short finishes without duplicates or overwrites',
    () async {
      final first = NodeStorageService();
      await first.init();
      await first.saveNodes([MeshNode(nodeNum: 1, longName: 'Newer')]);
      await first.close();

      // The app died after copying but before removing the key.
      await seedLegacy([_legacyNode(1, 'Older'), _legacyNode(2, 'Second')]);
      final again = NodeStorageService();
      await again.init();

      final nodes = await again.loadNodes();
      expect(nodes, hasLength(2));
      expect(nodes.firstWhere((n) => n.nodeNum == 1).longName, 'Newer');
      await again.close();
    },
  );

  test('an unreadable legacy value is kept for the next attempt', () async {
    await seedLegacy('{not json');
    final store = NodeStorageService();
    await store.init();
    expect(await store.loadNodes(), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(RadioScope.instance.prefsKey('nodes')), isTrue);
    await store.close();
  });

  test('saves keep a stored position and first-heard time, and persist '
      'across a reopen', () async {
    final store = NodeStorageService();
    await store.init();
    final firstHeard = DateTime(2026, 11, 1);
    await store.saveNodes([
      MeshNode(
        nodeNum: 7,
        longName: 'Mt Dandenong',
        latitude: -37.83,
        longitude: 145.35,
        firstHeard: firstHeard,
      ),
      MeshNode(nodeNum: 8, longName: 'Bendigo Relay'),
    ]);
    // A later update without a position must not erase the stored one.
    await store.saveNode(MeshNode(nodeNum: 7, longName: 'Mt D'));
    await store.close();

    final reopened = NodeStorageService();
    await reopened.init();
    final seven = await reopened.getNode(7);
    expect(seven?.longName, 'Mt D');
    expect(seven?.latitude, -37.83);
    expect(seven?.firstHeard, firstHeard);
    expect((await reopened.getNode(8))?.firstHeard, isNotNull);

    await reopened.deleteNodes({8});
    expect((await reopened.loadNodes()).map((n) => n.nodeNum), [7]);
    await reopened.clearNodes();
    expect(await reopened.loadNodes(), isEmpty);
    await reopened.close();
  });

  test('a large node list is written and read in chunks', () async {
    final store = NodeStorageService();
    await store.init();
    await store.saveNodes([
      for (var i = 1; i <= 2000; i++) MeshNode(nodeNum: i, longName: 'N$i'),
    ]);
    expect(await store.loadNodes(), hasLength(2000));
    await store.deleteNodes({for (var i = 1; i <= 1500; i++) i});
    expect(await store.loadNodes(), hasLength(500));
    await store.close();
  });
}
