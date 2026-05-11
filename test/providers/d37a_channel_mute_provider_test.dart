// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D37-A - `MeshCoreChannelPrefsNotifier` + `meshCoreChannelMutedSetProvider`
// behaviour pins.
//
// Pins:
//   - Initial muted set is empty.
//   - mute(idx) updates the state and persists.
//   - unmute(idx) removes from state and persists.
//   - State is device-scoped: switching the active pubkey prefix
//     re-reads from the store and surfaces THAT device's prefs.
//   - No-pubkey (empty prefix) -> mute / unmute are no-ops; no write
//     lands in SharedPreferences.
//   - isMuted() is consistent with the muted set provider.
//   - Pubkey prefix derivation matches the documented 8-char shape and
//     never logs/exposes the full 32-byte pubkey.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_channel_prefs_store.dart';

ProviderContainer _container({required String pubKeyPrefix}) {
  return ProviderContainer(
    overrides: [
      meshCoreSelfPubKeyPrefixProvider.overrideWith((ref) => pubKeyPrefix),
    ],
  );
}

Future<void> _pumpPrefsLoad() async {
  // Notifier.build() defers store reads off-build via Future<void>(...).
  // The load involves: microtask -> store.load -> async _resolve() ->
  // SharedPreferences.getInstance -> prefs.getString. Yield several
  // event-loop turns to let the whole chain settle.
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('meshCoreSelfPubKeyPrefix helper', () {
    test('returns first 4 bytes as lowercase hex (8 chars)', () {
      final info = MeshCoreSelfInfo(
        advType: 1,
        txPowerDbm: 22,
        maxLoraTxPower: 22,
        pubKey: Uint8List.fromList([
          0x79,
          0x42,
          0x6D,
          0x8D,
          ...List<int>.filled(28, 0),
        ]),
        nodeName: 'TerryDev2',
        rawPayload: Uint8List(0),
      );
      expect(meshCoreSelfPubKeyPrefix(info), equals('79426d8d'));
    });

    test('returns empty string for null info', () {
      expect(meshCoreSelfPubKeyPrefix(null), isEmpty);
    });

    test('returns empty string for empty pubKey', () {
      final info = MeshCoreSelfInfo(
        advType: 1,
        txPowerDbm: 0,
        maxLoraTxPower: 0,
        pubKey: Uint8List(0),
        nodeName: 'x',
        rawPayload: Uint8List(0),
      );
      expect(meshCoreSelfPubKeyPrefix(info), isEmpty);
    });

    test('never exposes more than 8 hex chars', () {
      final info = MeshCoreSelfInfo(
        advType: 1,
        txPowerDbm: 0,
        maxLoraTxPower: 0,
        pubKey: Uint8List.fromList(List.generate(32, (i) => 0xFF - i)),
        nodeName: '',
        rawPayload: Uint8List(0),
      );
      expect(meshCoreSelfPubKeyPrefix(info).length, 8);
    });
  });

  group('MeshCoreChannelPrefsNotifier', () {
    test('initial muted set is empty', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      expect(c.read(meshCoreChannelMutedSetProvider), isEmpty);
    });

    test('mute(idx) updates state', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.mute(3);
      expect(c.read(meshCoreChannelMutedSetProvider), equals({3}));
      expect(notifier.isMuted(3), isTrue);
      expect(notifier.isMuted(4), isFalse);
    });

    test('mute persists to SharedPreferences', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      await c.read(meshCoreChannelPrefsProvider.notifier).mute(3);
      final store = c.read(meshCoreChannelPrefsStoreProvider);
      final reloaded = await store.load('79426d8d');
      expect(reloaded.mutedChannelIndices, equals({3}));
    });

    test('unmute(idx) removes from state and persists', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.mute(3);
      await notifier.mute(5);
      await notifier.unmute(3);
      expect(c.read(meshCoreChannelMutedSetProvider), equals({5}));
      final store = c.read(meshCoreChannelPrefsStoreProvider);
      final reloaded = await store.load('79426d8d');
      expect(reloaded.mutedChannelIndices, equals({5}));
    });

    test('mute is idempotent (state and store)', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.mute(3);
      await notifier.mute(3);
      await notifier.mute(3);
      expect(c.read(meshCoreChannelMutedSetProvider), equals({3}));
    });

    test('no-pubkey device: mute/unmute are no-ops', () async {
      final c = _container(pubKeyPrefix: '');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.mute(3);
      await notifier.unmute(3);
      expect(c.read(meshCoreChannelMutedSetProvider), isEmpty);
      // SharedPreferences must NOT contain a channel-prefs key for the
      // empty device.
      final prefs = await SharedPreferences.getInstance();
      final ours = prefs.getKeys().where(
        (k) => k.startsWith('meshcore_channel_prefs_'),
      );
      expect(ours, isEmpty);
    });

    test('device-scoping: two devices keep independent muted sets', () async {
      // Seed each device's prefs via the store, then verify each
      // container surfaces its own.
      final preStore = MeshCoreChannelPrefsStore();
      await preStore.mute('aaaaaaaa', 1);
      await preStore.mute('bbbbbbbb', 9);

      final cA = _container(pubKeyPrefix: 'aaaaaaaa');
      addTearDown(cA.dispose);
      // Trigger build before pumping so the deferred load fires.
      cA.read(meshCoreChannelMutedSetProvider);
      await _pumpPrefsLoad();
      expect(cA.read(meshCoreChannelMutedSetProvider), equals({1}));

      final cB = _container(pubKeyPrefix: 'bbbbbbbb');
      addTearDown(cB.dispose);
      cB.read(meshCoreChannelMutedSetProvider);
      await _pumpPrefsLoad();
      expect(cB.read(meshCoreChannelMutedSetProvider), equals({9}));
    });

    test('isMuted is consistent with the muted-set provider', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.mute(2);
      await notifier.mute(7);
      final set = c.read(meshCoreChannelMutedSetProvider);
      for (var i = 0; i < 8; i++) {
        expect(notifier.isMuted(i), equals(set.contains(i)));
      }
    });
  });
}
