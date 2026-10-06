// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The world mesh node list is cached in a file, not in preferences, and a
// list left in preferences by an earlier build is dropped.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/world_mesh/services/node_cache_service.dart';
import 'package:socialmesh/models/world_mesh_node.dart';

WorldMeshNode _node(int nodeNum) => WorldMeshNode(
  nodeNum: nodeNum,
  longName: 'Node $nodeNum',
  shortName: 'N$nodeNum',
  hwModel: 'HELTEC_V3',
  role: 'CLIENT',
  // Coordinates are in 1e-7 degrees.
  latitude: -338000000 + nodeNum * 1000,
  longitude: 1512000000,
  seenBy: const {},
);

void main() {
  late Directory dir;
  late NodeCacheService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('node_cache_test');
    service = NodeCacheService(cacheDirectory: () async => dir);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('nodes round-trip through the cache file', () async {
    await service.cacheNodes([_node(1), _node(2)]);

    final cached = await service.getCachedNodes();
    expect(cached?.map((n) => n.nodeNum), [1, 2]);
    expect(cached?.first.longName, 'Node 1');
    expect(await service.isCacheValid(), isTrue);

    final status = await service.getCacheStatus();
    expect(status.hasCache, isTrue);
    expect(status.nodeCount, 2);
  });

  test('the node list is not stored in preferences', () async {
    await service.cacheNodes([_node(1)]);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('cached_mesh_nodes'), isFalse);
    expect(prefs.containsKey('cached_mesh_nodes_timestamp'), isTrue);
    expect(File('${dir.path}/world_mesh_nodes.json').existsSync(), isTrue);
  });

  test('a list left in preferences by an earlier build is dropped', () async {
    SharedPreferences.setMockInitialValues({'cached_mesh_nodes': '[]'});

    expect(await service.getCachedNodes(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('cached_mesh_nodes'), isFalse);
  });

  test('clearing removes the file and the timestamp', () async {
    await service.cacheNodes([_node(1)]);
    await service.clearCache();

    expect(File('${dir.path}/world_mesh_nodes.json').existsSync(), isFalse);
    expect(await service.getCachedNodes(), isNull);
    expect((await service.getCacheStatus()).hasCache, isFalse);
  });

  test('a corrupt cache file is cleared, not thrown', () async {
    await service.cacheNodes([_node(1)]);
    await File('${dir.path}/world_mesh_nodes.json').writeAsString('{oops');

    expect(await service.getCachedNodes(), isNull);
    expect(File('${dir.path}/world_mesh_nodes.json').existsSync(), isFalse);
  });
}
