// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D37-C-A - `MeshCoreChannelPrefsNotifier.setOrder` and
// `meshCoreChannelOrderProvider`.
//
// Pins:
//   - setOrder() updates state + persists.
//   - meshCoreChannelOrderProvider mirrors the persisted list.
//   - Device-scoping works (mirrors mute/hide tests).
//   - No-pubkey -> setOrder is a no-op; no SharedPreferences write
//     lands in a global key.
//   - setOrder() does NOT mutate the muted or hidden sets
//     (orthogonality with D37-A and D37-B-A).
//   - Log surface is redacted: `count=<N>` only - never the actual
//     order list.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/logging.dart';
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

  group('MeshCoreChannelPrefsNotifier.setOrder', () {
    test('initial order is empty', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      expect(c.read(meshCoreChannelOrderProvider), isEmpty);
    });

    test('setOrder updates state', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      await c.read(meshCoreChannelPrefsProvider.notifier).setOrder([3, 1, 0]);
      expect(c.read(meshCoreChannelOrderProvider), orderedEquals([3, 1, 0]));
    });

    test('setOrder persists to SharedPreferences', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      await c.read(meshCoreChannelPrefsProvider.notifier).setOrder([3, 1, 0]);
      final store = c.read(meshCoreChannelPrefsStoreProvider);
      final reloaded = await store.load('79426d8d');
      expect(reloaded.orderedChannelIndices, orderedEquals([3, 1, 0]));
    });

    test('setOrder dedupes (delegated to the store)', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      await c.read(meshCoreChannelPrefsProvider.notifier).setOrder([
        3,
        3,
        1,
        0,
        1,
      ]);
      expect(c.read(meshCoreChannelOrderProvider), orderedEquals([3, 1, 0]));
    });

    test('no-pubkey: setOrder is a no-op', () async {
      final c = _container(pubKeyPrefix: '');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      await c.read(meshCoreChannelPrefsProvider.notifier).setOrder([3, 1, 0]);
      expect(c.read(meshCoreChannelOrderProvider), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      final ours = prefs.getKeys().where(
        (k) => k.startsWith('meshcore_channel_prefs_'),
      );
      expect(ours, isEmpty);
    });

    test('device-scoping: two devices keep independent order lists', () async {
      // Pre-seed both devices via the real store (the providers will
      // read the same SharedPreferences singleton on build).
      final preStore = MeshCoreChannelPrefsStore();
      await preStore.setOrder('aaaaaaaa', [2, 1, 0]);
      await preStore.setOrder('bbbbbbbb', [0, 1, 2]);

      final cA = _container(pubKeyPrefix: 'aaaaaaaa');
      addTearDown(cA.dispose);
      cA.read(meshCoreChannelOrderProvider);
      await _pumpPrefsLoad();
      expect(cA.read(meshCoreChannelOrderProvider), orderedEquals([2, 1, 0]));

      final cB = _container(pubKeyPrefix: 'bbbbbbbb');
      addTearDown(cB.dispose);
      cB.read(meshCoreChannelOrderProvider);
      await _pumpPrefsLoad();
      expect(cB.read(meshCoreChannelOrderProvider), orderedEquals([0, 1, 2]));
    });

    test('setOrder does NOT mutate muted (orthogonality)', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.mute(4);
      await notifier.setOrder([3, 1, 0]);
      expect(c.read(meshCoreChannelMutedSetProvider), equals({4}));
      expect(c.read(meshCoreChannelOrderProvider), orderedEquals([3, 1, 0]));
    });

    test('setOrder does NOT mutate hidden (orthogonality)', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.hide(7);
      await notifier.setOrder([3, 1, 0]);
      expect(c.read(meshCoreChannelHiddenSetProvider), equals({7}));
      expect(c.read(meshCoreChannelOrderProvider), orderedEquals([3, 1, 0]));
    });

    test('mute/hide do NOT mutate the order list (orthogonality)', () async {
      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      final notifier = c.read(meshCoreChannelPrefsProvider.notifier);
      await notifier.setOrder([3, 1, 0]);
      await notifier.mute(4);
      await notifier.hide(7);
      expect(c.read(meshCoreChannelOrderProvider), orderedEquals([3, 1, 0]));
    });
  });

  group('D37-C-A: order log surface is count-only', () {
    test('event=channel.order.set carries count, not the index list', () async {
      final captured = <String>[];
      AppLogging.setAppLogSink((_, _, msg) => captured.add(msg));
      addTearDown(() => AppLogging.setAppLogSink((_, _, _) {}));

      final c = _container(pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      await _pumpPrefsLoad();
      await c.read(meshCoreChannelPrefsProvider.notifier).setOrder([3, 1, 0]);

      final setLines = captured
          .where((m) => m.contains('channel.order.set'))
          .toList();
      expect(setLines, isNotEmpty);
      final line = setLines.last;
      expect(line, contains('count=3'));
      expect(line, contains('device=79426d8d'));
      // Must NOT contain the index list in clear text.
      expect(line, isNot(contains('[3, 1, 0]')));
      expect(line, isNot(contains('3,1,0')));
    });
  });
}
