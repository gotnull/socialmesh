// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for [PeerSafetyManagerGateAdapter] — the bridge that lets
/// Ref-less protocol-layer code consult the live safety state.
///
/// Pins the contract:
///   1. `isBlocked` delegates to the live manager.
///   2. Default-safe: returns `false` before the manager has built.
///   3. Falls back to `false` if the underlying notifier read throws
///      (provider container disposed mid-call, etc.).
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:socialmesh/providers/peer_safety_providers.dart';
import 'package:socialmesh/services/protocol/sip/peer_safety_gate.dart';
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
  final dir = Directory.systemTemp.createTempSync('peer_safety_gate_test_');
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

  group('PeerSafetyManagerGateAdapter', () {
    test('delegates isBlocked / isMuted to the live manager', () async {
      final c = _newContainer();
      final mgr = c.read(peerSafetyManagerProvider.notifier);
      await c.read(peerSafetyManagerProvider.future);
      await mgr.block(0xAAAA);
      await mgr.mute(0xBBBB);

      final gate = c.read(peerSafetyGateProvider);
      expect(gate.isBlocked(0xAAAA), isTrue);
      expect(gate.isBlocked(0x9999), isFalse);
      expect(gate.isMuted(0xBBBB), isTrue);
      expect(gate.isMuted(0x9999), isFalse);
    });

    test('default-safe: returns false before the manager has loaded', () async {
      final c = _newContainer();
      // Read the gate WITHOUT awaiting the manager's build.
      final gate = c.read(peerSafetyGateProvider);
      // Manager state is AsyncLoading at this point — caches are
      // empty by definition; gate must return false everywhere.
      expect(gate.isBlocked(0x1234), isFalse);
      expect(gate.isMuted(0x1234), isFalse);
    });

    test('NoopPeerSafetyGate returns false for everything', () {
      const gate = NoopPeerSafetyGate();
      expect(gate.isBlocked(1), isFalse);
      expect(gate.isMuted(1), isFalse);
      expect(gate.isBlocked(0xFFFFFFFF), isFalse);
    });

    test('adapter survives provider container disposal mid-call', () async {
      final c = _newContainer();
      // Build the manager, capture the adapter, dispose the container,
      // then call the adapter — it should NOT crash; the catch block
      // returns the default-safe answer.
      await c.read(peerSafetyManagerProvider.future);
      final gate = c.read(peerSafetyGateProvider);
      c.dispose();
      // Hot-path safety: even if the underlying notifier read throws
      // because the container is gone, the gate must return false
      // instead of propagating the error to frame dispatch.
      expect(gate.isBlocked(0xDEAD), isFalse);
      expect(gate.isMuted(0xDEAD), isFalse);
    });
  });
}
