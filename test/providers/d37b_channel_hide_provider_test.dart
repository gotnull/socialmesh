// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D37-B-A - `MeshCoreChannelPrefsNotifier.hide / unhide / isHidden`
// + `meshCoreChannelHiddenSetProvider`.
//
// Pins:
//   - hide(idx) updates state + persists.
//   - unhide(idx) updates state + persists.
//   - isHidden() agrees with the muted-set provider semantics.
//   - Device-scoping works for the hidden set (mirrors the muted test).
//   - No-pubkey -> hide/unhide are no-ops; no SharedPreferences write
//     lands in a global key.
//   - Hide does NOT mute (orthogonality), and mute does NOT hide.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_channel_prefs_store.dart';

ProviderContainer _container({required String pubKeyPrefix}) {
  return ProviderContainer(
    overrides: [
      meshCoreSelfPubKeyPrefixProvider.overrideWith((ref) => pubKeyPrefix),
    ],
  );
}

Future<void> _pumpPrefsLoad() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MeshCoreChannelPrefsNotifier.hide / unhide', () {
    test('initial hidden set is empty', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      expect(c.read(meshCoreChannelHiddenSetProvider), isEmpty);
    });

    test('hide(idx) updates state', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.hide(3);
      expect(c.read(meshCoreChannelHiddenSetProvider), equals({3}));
      expect(notifier.isHidden(3), isTrue);
      expect(notifier.isHidden(4), isFalse);
    });

    test('hide persists to SharedPreferences', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      await c.read(meshCoreChannelPrefsProvider.notifier).hide(3);
      final store = c.read(meshCoreChannelPrefsStoreProvider);
      final reloaded = await store.load('79426d8d');
      expect(reloaded.hiddenChannelIndices, equals({3}));
    });

    test('unhide(idx) removes from state and persists', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.hide(3);
      await notifier.hide(5);
      await notifier.unhide(3);
      expect(c.read(meshCoreChannelHiddenSetProvider), equals({5}));
    });

    test('hide is idempotent', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.hide(3);
      await notifier.hide(3);
      await notifier.hide(3);
      expect(c.read(meshCoreChannelHiddenSetProvider), equals({3}));
    });

    test('no-pubkey device: hide/unhide are no-ops', () async {
      final c = _container(pubKeyPrefix: '');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.hide(3);
      await notifier.unhide(3);
      expect(c.read(meshCoreChannelHiddenSetProvider), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      final ours = prefs.getKeys().where(
        (k) => k.startsWith('meshcore_channel_prefs_'),
      );
      expect(ours, isEmpty);
    });

    test('device-scoping: two devices keep independent hidden sets', () async {
      final preStore = MeshCoreChannelPrefsStore();
      await preStore.hide('aaaaaaaa', 1);
      await preStore.hide('bbbbbbbb', 9);

      final cA = _container(pubKeyPrefix: 'aaaaaaaa');
      addTearDown(cA.dispose);
      cA.read(meshCoreChannelHiddenSetProvider);
      await _pumpPrefsLoad();
      expect(cA.read(meshCoreChannelHiddenSetProvider), equals({1}));

      final cB = _container(pubKeyPrefix: 'bbbbbbbb');
      addTearDown(cB.dispose);
      cB.read(meshCoreChannelHiddenSetProvider);
      await _pumpPrefsLoad();
      expect(cB.read(meshCoreChannelHiddenSetProvider), equals({9}));
    });

    test('hide does NOT mute (orthogonality)', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.hide(3);
      expect(c.read(meshCoreChannelMutedSetProvider), isEmpty);
      expect(notifier.isMuted(3), isFalse);
    });

    test('mute does NOT hide (orthogonality)', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.mute(3);
      expect(c.read(meshCoreChannelHiddenSetProvider), isEmpty);
      expect(notifier.isHidden(3), isFalse);
    });

    test('isHidden is consistent with the hidden-set provider', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.hide(2);
      await notifier.hide(7);
      final set = c.read(meshCoreChannelHiddenSetProvider);
      for (var i = 0; i < 8; i++) {
        expect(notifier.isHidden(i), equals(set.contains(i)));
      }
    });

    test('a channel can be both muted and hidden at once', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.mute(4);
      await notifier.hide(4);
      expect(c.read(meshCoreChannelMutedSetProvider), equals({4}));
      expect(c.read(meshCoreChannelHiddenSetProvider), equals({4}));
      // Unmuting must not unhide.
      await notifier.unmute(4);
      expect(c.read(meshCoreChannelMutedSetProvider), isEmpty);
      expect(c.read(meshCoreChannelHiddenSetProvider), equals({4}));
      // Unhiding must not re-mute.
      await notifier.unhide(4);
      expect(c.read(meshCoreChannelMutedSetProvider), isEmpty);
      expect(c.read(meshCoreChannelHiddenSetProvider), isEmpty);
    });
  });
}
