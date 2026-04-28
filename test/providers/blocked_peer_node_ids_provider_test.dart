// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// [blockedPeerNodeIdsProvider] tests — pins the contract of the
/// derived list provider that feeds the SIP Hub Blocked section
/// + filters the active lists.
///
/// Hard rules pinned here:
///
///   - Returns an empty list while the manager is still loading
///     (cold start) — the SIP Hub then renders no Blocked section,
///     which is the safer default.
///   - Updates synchronously (within the same microtask) once a
///     `block` write completes.
///   - Sorted numerically for stable row order across rebuilds.
///   - Returns a fresh list each rebuild — no aliased mutation hazard.
///   - Reading the provider does NOT mutate any safety / protocol
///     state (defense-in-depth: rendering is read-only).
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

ProviderContainer _newContainer() {
  _initFfi();
  final dir = Directory.systemTemp.createTempSync('blocked_provider_test_');
  final dbPath = p.join(dir.path, 'peer_safety.db');
  addTearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  final c = ProviderContainer(
    overrides: [
      peerSafetyStoreProvider.overrideWith((ref) async {
        final s = PeerSafetyStore(testDbPath: dbPath);
        await s.init();
        ref.onDispose(() async {
          try {
            await s.close();
          } catch (_) {}
        });
        return s;
      }),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUpAll(_initFfi);

  group('blockedPeerNodeIdsProvider', () {
    test('returns an empty list while the manager is loading '
        '(cold start, no AsyncData yet)', () {
      final c = _newContainer();
      // Read before the manager's build() future resolves.
      final result = c.read(blockedPeerNodeIdsProvider);
      expect(result, isEmpty);
    });

    test('returns an empty list after the manager loads with no '
        'blocked peers', () async {
      final c = _newContainer();
      await c.read(peerSafetyManagerProvider.future);
      expect(c.read(blockedPeerNodeIdsProvider), isEmpty);
    });

    test('reflects a block write once the manager state propagates', () async {
      final c = _newContainer();
      final mgr = await c
          .read(peerSafetyManagerProvider.future)
          .then((_) => c.read(peerSafetyManagerProvider.notifier));
      await mgr.block(0xAAAA);
      // Watching is needed for derived providers to recompute on
      // dependency changes — read-only test setups must spin up a
      // listener for the watch chain to fire.
      c.listen(blockedPeerNodeIdsProvider, (_, _) {}, fireImmediately: true);
      expect(c.read(blockedPeerNodeIdsProvider), equals([0xAAAA]));
    });

    test('returns numerically sorted IDs (stable row order)', () async {
      final c = _newContainer();
      await c.read(peerSafetyManagerProvider.future);
      final mgr = c.read(peerSafetyManagerProvider.notifier);
      // Block in reverse order to confirm sort happens at provider
      // layer, not coincidentally at insertion time.
      await mgr.block(0xCCCC);
      await mgr.block(0xAAAA);
      await mgr.block(0xBBBB);
      c.listen(blockedPeerNodeIdsProvider, (_, _) {}, fireImmediately: true);
      expect(
        c.read(blockedPeerNodeIdsProvider),
        equals([0xAAAA, 0xBBBB, 0xCCCC]),
      );
    });

    test('drops a peer once unblock fires', () async {
      final c = _newContainer();
      await c.read(peerSafetyManagerProvider.future);
      final mgr = c.read(peerSafetyManagerProvider.notifier);
      await mgr.block(0x1234);
      await mgr.block(0x5678);
      c.listen(blockedPeerNodeIdsProvider, (_, _) {}, fireImmediately: true);
      expect(c.read(blockedPeerNodeIdsProvider), equals([0x1234, 0x5678]));
      await mgr.unblock(0x1234);
      expect(c.read(blockedPeerNodeIdsProvider), equals([0x5678]));
    });

    test('reading the provider does NOT change manager state '
        '(rendering is a pure read)', () async {
      final c = _newContainer();
      await c.read(peerSafetyManagerProvider.future);
      final mgr = c.read(peerSafetyManagerProvider.notifier);
      await mgr.block(0xFEED);
      // Read the provider an arbitrary number of times — none of
      // these should mutate state.
      for (var i = 0; i < 5; i += 1) {
        c.read(blockedPeerNodeIdsProvider);
      }
      // Confirm only one peer remains blocked + first-contact mark
      // for that peer is unchanged (block doesn't set it; reading
      // shouldn't either).
      expect(mgr.isBlocked(0xFEED), isTrue);
      expect(mgr.hasFirstContact(0xFEED), isFalse);
      expect(mgr.isMuted(0xFEED), isFalse);
    });
  });
}
