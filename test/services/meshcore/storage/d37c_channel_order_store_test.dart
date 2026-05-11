// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D37-C-A - setOrder on `MeshCoreChannelPrefsStore`.
//
// Pinned invariants:
//   - setOrder() persists the order list verbatim (post-dedup).
//   - Duplicate slot indices in the input are deduped (first wins).
//   - Out-of-range entries are dropped (< 0 or > 255).
//   - muted and hidden fields are preserved across setOrder().
//   - Corrupt JSON returns empty prefs without throwing.
//   - clear() removes the on-disk key (so order is wiped along with
//     muted and hidden).
//   - Persisted blob never contains PSK / channel-code / channel-name
//     material.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_channel_prefs_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MeshCoreChannelPrefsStore.setOrder', () {
    test('setOrder persists the order list verbatim', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.setOrder('79426d8d', [3, 1, 0, 2]);
      final loaded = await store.load('79426d8d');
      expect(loaded.orderedChannelIndices, orderedEquals([3, 1, 0, 2]));
    });

    test('setOrder dedupes (first occurrence wins)', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.setOrder('79426d8d', [3, 1, 0, 3, 2, 1]);
      final loaded = await store.load('79426d8d');
      expect(loaded.orderedChannelIndices, orderedEquals([3, 1, 0, 2]));
    });

    test('setOrder drops out-of-range entries', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.setOrder('79426d8d', [-1, 0, 256, 999, 1, -5]);
      final loaded = await store.load('79426d8d');
      expect(loaded.orderedChannelIndices, orderedEquals([0, 1]));
    });

    test('setOrder is idempotent (same order back is a no-op)', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.setOrder('79426d8d', [3, 1, 0]);
      await store.setOrder('79426d8d', [3, 1, 0]);
      final loaded = await store.load('79426d8d');
      expect(loaded.orderedChannelIndices, orderedEquals([3, 1, 0]));
    });

    test('setOrder preserves the muted and hidden sets', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.mute('79426d8d', 4);
      await store.hide('79426d8d', 7);
      await store.setOrder('79426d8d', [3, 1, 0]);
      final loaded = await store.load('79426d8d');
      expect(loaded.mutedChannelIndices, equals({4}));
      expect(loaded.hiddenChannelIndices, equals({7}));
      expect(loaded.orderedChannelIndices, orderedEquals([3, 1, 0]));
    });

    test('muting / hiding does not touch the order list', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.setOrder('79426d8d', [3, 1, 0]);
      await store.mute('79426d8d', 4);
      await store.hide('79426d8d', 7);
      final loaded = await store.load('79426d8d');
      expect(loaded.orderedChannelIndices, orderedEquals([3, 1, 0]));
    });

    test('clear() wipes the order list along with muted and hidden', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.mute('79426d8d', 1);
      await store.hide('79426d8d', 2);
      await store.setOrder('79426d8d', [3, 1, 0]);
      await store.clear('79426d8d');
      final loaded = await store.load('79426d8d');
      expect(loaded.mutedChannelIndices, isEmpty);
      expect(loaded.hiddenChannelIndices, isEmpty);
      expect(loaded.orderedChannelIndices, isEmpty);
    });

    test('two devices keep independent order lists', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.setOrder('aaaaaaaa', [2, 1, 0]);
      await store.setOrder('bbbbbbbb', [0, 1, 2]);
      final a = await store.load('aaaaaaaa');
      final b = await store.load('bbbbbbbb');
      expect(a.orderedChannelIndices, orderedEquals([2, 1, 0]));
      expect(b.orderedChannelIndices, orderedEquals([0, 1, 2]));
    });

    test('corrupt JSON returns empty prefs (no throw)', () async {
      SharedPreferences.setMockInitialValues({
        'meshcore_channel_prefs_79426d8d': '{ "order":',
      });
      final store = MeshCoreChannelPrefsStore();
      final loaded = await store.load('79426d8d');
      expect(loaded.orderedChannelIndices, isEmpty);
      expect(loaded.mutedChannelIndices, isEmpty);
      expect(loaded.hiddenChannelIndices, isEmpty);
    });

    test('empty device-key is a no-op for setOrder', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.setOrder('79426d8d', [1, 2]);
      await store.setOrder('', [9, 9, 9]);
      final loaded = await store.load('79426d8d');
      expect(loaded.orderedChannelIndices, orderedEquals([1, 2]));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('meshcore_channel_prefs_'), isFalse);
    });

    test(
      'persisted blob carries the order list but no PSK / code / name',
      () async {
        final store = MeshCoreChannelPrefsStore();
        await store.setOrder('79426d8d', [3, 1, 0]);
        final prefs = await SharedPreferences.getInstance();
        final blob = prefs.getString('meshcore_channel_prefs_79426d8d')!;
        final pskShape = RegExp(r'[0-9a-fA-F]{32}');
        final channelCodeShape = RegExp(r'[A-Za-z0-9#_-]+:[0-9a-fA-F]{32}');
        expect(pskShape.hasMatch(blob), isFalse);
        expect(channelCodeShape.hasMatch(blob), isFalse);
        final decoded = jsonDecode(blob) as Map<String, dynamic>;
        expect(decoded['order'], orderedEquals([3, 1, 0]));
      },
    );
  });
}
