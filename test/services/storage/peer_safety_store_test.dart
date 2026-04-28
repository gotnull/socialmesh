// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Persistence tests for [PeerSafetyStore]. Mirrors the
/// `OverlayLinkStore` test pattern — sqflite_common_ffi for in-memory
/// SQLite, schema round-trip, filter queries, idempotency.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:socialmesh/services/storage/peer_safety_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _ffiInitialised = false;
void _initFfi() {
  if (_ffiInitialised) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  _ffiInitialised = true;
}

Future<PeerSafetyStore> _newStore() async {
  _initFfi();
  final dir = Directory.systemTemp.createTempSync('peer_safety_test_');
  final path = p.join(dir.path, 'peer_safety.db');
  final store = PeerSafetyStore(testDbPath: path);
  await store.init();
  addTearDown(() async {
    try {
      await store.close();
    } catch (_) {}
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });
  return store;
}

void main() {
  setUpAll(_initFfi);

  group('PeerSafetyStore', () {
    test('init creates schema; count starts at 0', () async {
      final store = await _newStore();
      expect(store.isOpen, isTrue);
      expect(await store.count(), equals(0));
    });

    test('upsert / getByPeerNodeId round-trip preserves every field', () async {
      final store = await _newStore();
      const record = PeerSafetyRecord(
        peerNodeId: 0xABCD1234,
        state: NodeSafetyState.blocked,
        firstHandshakeMs: 1700000000000,
        blockedAtMs: 1700000000005,
        mutedAtMs: null,
        reasonCode: 'unsolicited_dm',
        notes: 'kept tapping send',
        lastStateChangeMs: 1700000000010,
      );
      await store.upsert(record);
      final loaded = await store.getByPeerNodeId(0xABCD1234);
      expect(loaded, isNotNull);
      expect(loaded!.peerNodeId, equals(0xABCD1234));
      expect(loaded.state, equals(NodeSafetyState.blocked));
      expect(loaded.firstHandshakeMs, equals(1700000000000));
      expect(loaded.blockedAtMs, equals(1700000000005));
      expect(loaded.mutedAtMs, isNull);
      expect(loaded.reasonCode, equals('unsolicited_dm'));
      expect(loaded.notes, equals('kept tapping send'));
      expect(loaded.lastStateChangeMs, equals(1700000000010));
    });

    test('upsert replaces an existing row (same primary key)', () async {
      final store = await _newStore();
      await store.upsert(
        const PeerSafetyRecord(
          peerNodeId: 0x1111,
          state: NodeSafetyState.neutral,
          lastStateChangeMs: 1,
        ),
      );
      await store.upsert(
        const PeerSafetyRecord(
          peerNodeId: 0x1111,
          state: NodeSafetyState.blocked,
          blockedAtMs: 1700,
          lastStateChangeMs: 1700,
        ),
      );
      final loaded = await store.getByPeerNodeId(0x1111);
      expect(loaded!.state, equals(NodeSafetyState.blocked));
      expect(loaded.blockedAtMs, equals(1700));
      expect(await store.count(), equals(1));
    });

    test('getByState filters correctly', () async {
      final store = await _newStore();
      await store.upsert(
        const PeerSafetyRecord(
          peerNodeId: 1,
          state: NodeSafetyState.blocked,
          lastStateChangeMs: 1,
        ),
      );
      await store.upsert(
        const PeerSafetyRecord(
          peerNodeId: 2,
          state: NodeSafetyState.muted,
          lastStateChangeMs: 1,
        ),
      );
      await store.upsert(
        const PeerSafetyRecord(
          peerNodeId: 3,
          state: NodeSafetyState.blocked,
          lastStateChangeMs: 1,
        ),
      );
      await store.upsert(
        const PeerSafetyRecord(
          peerNodeId: 4,
          state: NodeSafetyState.neutral,
          lastStateChangeMs: 1,
        ),
      );

      final blocked = await store.getByState(NodeSafetyState.blocked);
      expect(blocked.map((r) => r.peerNodeId).toSet(), equals({1, 3}));

      final muted = await store.getByState(NodeSafetyState.muted);
      expect(muted.map((r) => r.peerNodeId).toSet(), equals({2}));

      final ids = await store.getBlockedPeerNodeIds();
      expect(ids.toSet(), equals({1, 3}));
    });

    test('getHandshakenPeerNodeIds returns only rows with non-null '
        'firstHandshakeMs', () async {
      final store = await _newStore();
      await store.upsert(
        const PeerSafetyRecord(
          peerNodeId: 10,
          state: NodeSafetyState.neutral,
          firstHandshakeMs: 100,
          lastStateChangeMs: 100,
        ),
      );
      await store.upsert(
        const PeerSafetyRecord(
          peerNodeId: 11,
          state: NodeSafetyState.blocked,
          firstHandshakeMs: null, // never accepted
          lastStateChangeMs: 200,
        ),
      );
      await store.upsert(
        const PeerSafetyRecord(
          peerNodeId: 12,
          state: NodeSafetyState.neutral,
          firstHandshakeMs: 300,
          lastStateChangeMs: 300,
        ),
      );

      final ids = await store.getHandshakenPeerNodeIds();
      expect(ids.toSet(), equals({10, 12}));
    });

    test('delete is idempotent and returns affected row count', () async {
      final store = await _newStore();
      await store.upsert(
        const PeerSafetyRecord(
          peerNodeId: 7,
          state: NodeSafetyState.muted,
          lastStateChangeMs: 1,
        ),
      );
      expect(await store.delete(7), equals(1));
      expect(await store.delete(7), equals(0));
      expect(await store.getByPeerNodeId(7), isNull);
    });

    test('NodeSafetyState.fromCode tolerates unknown / null', () {
      expect(NodeSafetyState.fromCode(null), NodeSafetyState.neutral);
      expect(NodeSafetyState.fromCode('not_a_state'), NodeSafetyState.neutral);
      expect(NodeSafetyState.fromCode('blocked'), NodeSafetyState.blocked);
      expect(NodeSafetyState.fromCode('trusted'), NodeSafetyState.trusted);
      expect(NodeSafetyState.fromCode('unsafe'), NodeSafetyState.unsafe);
    });

    test('persistence survives close + re-init on the same path', () async {
      _initFfi();
      final dir = Directory.systemTemp.createTempSync('peer_safety_persist_');
      final path = p.join(dir.path, 'peer_safety.db');
      addTearDown(() {
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {}
      });

      final s1 = PeerSafetyStore(testDbPath: path);
      await s1.init();
      await s1.upsert(
        const PeerSafetyRecord(
          peerNodeId: 0xDEAD,
          state: NodeSafetyState.blocked,
          blockedAtMs: 9999,
          lastStateChangeMs: 9999,
        ),
      );
      await s1.close();

      final s2 = PeerSafetyStore(testDbPath: path);
      await s2.init();
      final loaded = await s2.getByPeerNodeId(0xDEAD);
      expect(loaded, isNotNull);
      expect(loaded!.state, equals(NodeSafetyState.blocked));
      expect(loaded.blockedAtMs, equals(9999));
      await s2.close();
    });
  });
}
