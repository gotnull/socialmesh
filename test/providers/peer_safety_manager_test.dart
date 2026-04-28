// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// [PeerSafetyManager] tests — hot-path queries, mutation paths,
/// serialised writes, and the durability contract (cache + DB stay
/// consistent across re-init).
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:socialmesh/providers/peer_safety_providers.dart';
import 'package:socialmesh/services/storage/peer_safety_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _ffiInitialised = false;
void _initFfi() {
  if (_ffiInitialised) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  _ffiInitialised = true;
}

/// Build a ProviderContainer wired to an isolated tempfile-backed
/// PeerSafetyStore. Returns the container plus the underlying path
/// so subsequent containers can re-init against the same DB to
/// verify durability.
({ProviderContainer container, String dbPath}) _newContainer({String? path}) {
  _initFfi();
  final dir = path == null
      ? Directory.systemTemp.createTempSync('peer_safety_mgr_test_')
      : null;
  final dbPath = path ?? p.join(dir!.path, 'peer_safety.db');
  if (dir != null) {
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });
  }

  final container = ProviderContainer(
    overrides: [
      peerSafetyStoreProvider.overrideWith((ref) async {
        final store = PeerSafetyStore(testDbPath: dbPath);
        await store.init();
        ref.onDispose(() async {
          try {
            await store.close();
          } catch (_) {}
        });
        return store;
      }),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, dbPath: dbPath);
}

Future<PeerSafetyManager> _readyManager(ProviderContainer c) async {
  // Force the AsyncNotifier to build by reading its state.future.
  await c.read(peerSafetyManagerProvider.future);
  return c.read(peerSafetyManagerProvider.notifier);
}

void main() {
  setUpAll(_initFfi);

  group('PeerSafetyManager — hot-path queries', () {
    test('isBlocked / isMuted / hasFirstContact return false on a fresh '
        'install', () async {
      final c = _newContainer().container;
      final mgr = await _readyManager(c);
      expect(mgr.isBlocked(0xAA), isFalse);
      expect(mgr.isMuted(0xAA), isFalse);
      expect(mgr.hasFirstContact(0xAA), isFalse);
    });

    test('block() flips isBlocked sync immediately after the await', () async {
      final c = _newContainer().container;
      final mgr = await _readyManager(c);
      await mgr.block(0xBEEF);
      expect(mgr.isBlocked(0xBEEF), isTrue);
      expect(mgr.isBlocked(0xCAFE), isFalse);
    });

    test(
      'mute() flips isMuted sync; block() takes priority semantics',
      () async {
        final c = _newContainer().container;
        final mgr = await _readyManager(c);
        await mgr.mute(0xAA);
        expect(mgr.isMuted(0xAA), isTrue);
        // block trumps mute in cache: the muted set may keep the entry,
        // but the blocked set is the authoritative gate.
        await mgr.block(0xAA);
        expect(mgr.isBlocked(0xAA), isTrue);
      },
    );

    test('markFirstHandshake() flips hasFirstContact sync', () async {
      final c = _newContainer().container;
      final mgr = await _readyManager(c);
      expect(mgr.hasFirstContact(0xDEAD), isFalse);
      await mgr.markFirstHandshake(0xDEAD, 1700000000000);
      expect(mgr.hasFirstContact(0xDEAD), isTrue);
    });

    test(
      'markFirstHandshake is idempotent — only first timestamp is kept',
      () async {
        final c = _newContainer();
        final mgr = await _readyManager(c.container);
        await mgr.markFirstHandshake(0x123, 1000);
        await mgr.markFirstHandshake(0x123, 9999);

        // Re-initialise against the same DB to read the persisted row.
        c.container.dispose();
        final c2 = _newContainer(path: c.dbPath).container;
        await _readyManager(c2);
        final store = await c2.read(peerSafetyStoreProvider.future);
        final row = await store.getByPeerNodeId(0x123);
        expect(row, isNotNull);
        expect(
          row!.firstHandshakeMs,
          equals(1000),
          reason: 'second markFirstHandshake must not overwrite the first',
        );
      },
    );
  });

  group('PeerSafetyManager — mutation paths', () {
    test('unblock() removes from cache and clears blocked_at_ms', () async {
      final c = _newContainer();
      final mgr = await _readyManager(c.container);
      await mgr.block(0x55, reasonCode: 'spam');
      expect(mgr.isBlocked(0x55), isTrue);
      await mgr.unblock(0x55);
      expect(mgr.isBlocked(0x55), isFalse);

      // The row carried a reasonCode, so it survives unblock as
      // neutral (durable history). Verify on the store.
      final store = await c.container.read(peerSafetyStoreProvider.future);
      final row = await store.getByPeerNodeId(0x55);
      expect(row, isNotNull);
      expect(row!.state, NodeSafetyState.neutral);
      expect(row.blockedAtMs, isNull);
      expect(row.reasonCode, equals('spam'));
    });

    test('unblock() deletes the row when nothing else is on it', () async {
      final c = _newContainer();
      final mgr = await _readyManager(c.container);
      await mgr.block(0x99); // no reasonCode, no firstHandshake
      await mgr.unblock(0x99);

      final store = await c.container.read(peerSafetyStoreProvider.future);
      expect(await store.getByPeerNodeId(0x99), isNull);
    });

    test('mute() does not downgrade an existing block', () async {
      final c = _newContainer();
      final mgr = await _readyManager(c.container);
      await mgr.block(0x77);
      await mgr.mute(0x77);
      // block remains
      expect(mgr.isBlocked(0x77), isTrue);
      final store = await c.container.read(peerSafetyStoreProvider.future);
      final row = await store.getByPeerNodeId(0x77);
      expect(row!.state, NodeSafetyState.blocked);
    });

    test('setSafetyState transitions: neutral → blocked → neutral', () async {
      final c = _newContainer();
      final mgr = await _readyManager(c.container);
      await mgr.setSafetyState(0xABCD, NodeSafetyState.blocked);
      expect(mgr.isBlocked(0xABCD), isTrue);
      await mgr.setSafetyState(0xABCD, NodeSafetyState.neutral);
      expect(mgr.isBlocked(0xABCD), isFalse);
    });

    test('setSafetyState supports trusted / unsafe v2 states without '
        'breaking caches', () async {
      final c = _newContainer();
      final mgr = await _readyManager(c.container);
      await mgr.setSafetyState(0x1, NodeSafetyState.trusted);
      await mgr.setSafetyState(0x2, NodeSafetyState.unsafe);
      // Neither shows up in the block/mute caches.
      expect(mgr.isBlocked(0x1), isFalse);
      expect(mgr.isMuted(0x1), isFalse);
      expect(mgr.isBlocked(0x2), isFalse);
      expect(mgr.isMuted(0x2), isFalse);
      // Persisted in the DB.
      final store = await c.container.read(peerSafetyStoreProvider.future);
      expect(
        (await store.getByPeerNodeId(0x1))!.state,
        NodeSafetyState.trusted,
      );
      expect((await store.getByPeerNodeId(0x2))!.state, NodeSafetyState.unsafe);
    });
  });

  group('PeerSafetyManager — durability', () {
    test(
      'cache rebuilds from DB on re-init (new container, same DB path)',
      () async {
        final first = _newContainer();
        final mgr1 = await _readyManager(first.container);
        await mgr1.block(0x111, reasonCode: 'x');
        await mgr1.mute(0x222);
        await mgr1.markFirstHandshake(0x333, 4242);
        first.container.dispose();

        final second = _newContainer(path: first.dbPath);
        final mgr2 = await _readyManager(second.container);
        expect(mgr2.isBlocked(0x111), isTrue);
        expect(mgr2.isMuted(0x222), isTrue);
        expect(mgr2.hasFirstContact(0x333), isTrue);
      },
    );

    test('serialised writes — concurrent block calls all persist', () async {
      final c = _newContainer();
      final mgr = await _readyManager(c.container);
      // Fire many overlapping blocks; the manager must serialise
      // them so every write lands in the DB and the cache.
      final futures = <Future<void>>[];
      for (var i = 0; i < 20; i++) {
        futures.add(mgr.block(0x1000 + i));
      }
      await Future.wait(futures);

      for (var i = 0; i < 20; i++) {
        expect(mgr.isBlocked(0x1000 + i), isTrue);
      }
      final store = await c.container.read(peerSafetyStoreProvider.future);
      final ids = await store.getBlockedPeerNodeIds();
      expect(ids.toSet(), equals({for (var i = 0; i < 20; i++) 0x1000 + i}));
    });
  });
}
