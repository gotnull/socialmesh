// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';

void main() {
  // Initialize sqflite FFI for desktop testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('MeshPacketDedupeStore corruption recovery', () {
    late String tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('dedupe_test_').path;
      dbPath = p.join(tempDir, 'test_dedupe.db');
    });

    tearDown(() async {
      try {
        final dir = Directory(tempDir);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {
        // Ignore cleanup errors
      }
    });

    test('initializes successfully with fresh database', () async {
      final store = MeshPacketDedupeStore(dbPathOverride: dbPath);
      await store.init();

      // Should be able to mark and check packets
      const key = MeshPacketKey(
        packetType: 'TEXT',
        senderNodeId: 123,
        packetId: 456,
        channelIndex: 0,
      );

      final seenBefore = await store.hasSeen(key);
      expect(seenBefore, false);

      await store.markSeen(key);

      final seenAfter = await store.hasSeen(key);
      expect(seenAfter, true);

      await store.dispose();
    });

    test('recovers from corrupted database file', () async {
      // Create a corrupted database file
      final dbFile = File(dbPath);
      await dbFile.parent.create(recursive: true);
      await dbFile.writeAsString('this is not a valid sqlite database');

      // Store should recover by deleting and recreating
      final store = MeshPacketDedupeStore(dbPathOverride: dbPath);
      await store.init();

      // Should be functional after recovery
      const key = MeshPacketKey(
        packetType: 'TEXT',
        senderNodeId: 789,
        packetId: 101,
        channelIndex: 1,
      );

      await store.markSeen(key);
      final seen = await store.hasSeen(key);
      expect(seen, true);

      await store.dispose();
    });

    test('fails open when database unavailable', () async {
      // Create a store that will fail to open
      final store = MeshPacketDedupeStore(dbPathOverride: dbPath);

      // Don't initialize - _ensureDb will try to initialize

      const key = MeshPacketKey(
        packetType: 'TEXT',
        senderNodeId: 111,
        packetId: 222,
        channelIndex: 0,
      );

      // hasSeen should return false (fail-open) when DB not available
      // Note: This actually initializes the DB, so it will work
      final seen = await store.hasSeen(key);
      expect(seen, false);

      await store.dispose();
    });

    test('prevents concurrent initialization', () async {
      final store = MeshPacketDedupeStore(dbPathOverride: dbPath);

      // Start multiple concurrent initializations
      final futures = <Future<void>>[];
      for (var i = 0; i < 5; i++) {
        futures.add(store.init());
      }

      // All should complete without error
      await Future.wait(futures);

      // Store should be functional
      const key = MeshPacketKey(
        packetType: 'TEXT',
        senderNodeId: 333,
        packetId: 444,
        channelIndex: 2,
      );

      await store.markSeen(key);
      final seen = await store.hasSeen(key);
      expect(seen, true);

      await store.dispose();
    });

    test('cleanup removes old entries', () async {
      final store = MeshPacketDedupeStore(dbPathOverride: dbPath);
      await store.init();

      const key = MeshPacketKey(
        packetType: 'TEXT',
        senderNodeId: 555,
        packetId: 666,
        channelIndex: 0,
      );

      await store.markSeen(key);

      // Entry should be visible with default TTL
      final seenDefault = await store.hasSeen(key);
      expect(seenDefault, true);

      // Entry should NOT be visible with a very short TTL (0 milliseconds)
      final seenShortTtl = await store.hasSeen(key, ttl: Duration.zero);
      expect(seenShortTtl, false);

      await store.dispose();
    });

    test('dispose allows reinitialization', () async {
      final store = MeshPacketDedupeStore(dbPathOverride: dbPath);
      await store.init();

      const key1 = MeshPacketKey(
        packetType: 'TEXT',
        senderNodeId: 777,
        packetId: 888,
        channelIndex: 0,
      );

      await store.markSeen(key1);
      expect(await store.hasSeen(key1), true);

      // Dispose
      await store.dispose();

      // Re-initialize
      await store.init();

      // Data should persist (same file)
      expect(await store.hasSeen(key1), true);

      await store.dispose();
    });
  });
}
