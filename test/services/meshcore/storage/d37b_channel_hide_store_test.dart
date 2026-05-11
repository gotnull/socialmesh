// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D37-B-A - hide / unhide on `MeshCoreChannelPrefsStore`.
//
// Pinned invariants:
//   - hide() / unhide() round-trip; idempotent.
//   - muted and hidden coexist independently (orthogonality).
//   - JSON shape preserves muted + hidden + order; reordering one set
//     does not corrupt the other.
//   - Corrupt JSON returns empty prefs without throwing.
//   - clear() removes all three fields together.
//   - No PSK / channel-code / full-key material appears in the
//     SharedPreferences keyspace or the persisted blob.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_channel_prefs_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MeshCoreChannelPrefs.hidden serialization', () {
    test('round-trips a populated hidden set alongside muted', () {
      const original = MeshCoreChannelPrefs(
        mutedChannelIndices: {0, 5},
        hiddenChannelIndices: {2, 7},
      );
      final restored = MeshCoreChannelPrefs.fromJson(original.toJson());
      expect(restored.mutedChannelIndices, equals({0, 5}));
      expect(restored.hiddenChannelIndices, equals({2, 7}));
    });

    test('hidden writes sorted list', () {
      const original = MeshCoreChannelPrefs(hiddenChannelIndices: {7, 0, 3});
      final json = original.toJson();
      expect(json['hidden'], orderedEquals([0, 3, 7]));
    });

    test('rejects out-of-range integers on decode', () {
      final restored = MeshCoreChannelPrefs.fromJson(<String, dynamic>{
        'muted': [],
        'hidden': [0, -1, 999, 3, 'oops'],
        'order': [],
      });
      expect(restored.hiddenChannelIndices, equals({0, 3}));
    });
  });

  group('MeshCoreChannelPrefsStore hide / unhide', () {
    test('hide() persists', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.hide('79426d8d', 3);
      final loaded = await store.load('79426d8d');
      expect(loaded.hiddenChannelIndices, equals({3}));
    });

    test('hide() is idempotent', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.hide('79426d8d', 3);
      await store.hide('79426d8d', 3);
      await store.hide('79426d8d', 3);
      final loaded = await store.load('79426d8d');
      expect(loaded.hiddenChannelIndices, equals({3}));
    });

    test('unhide() persists', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.hide('79426d8d', 3);
      await store.hide('79426d8d', 5);
      await store.unhide('79426d8d', 3);
      final loaded = await store.load('79426d8d');
      expect(loaded.hiddenChannelIndices, equals({5}));
    });

    test('unhide() is idempotent', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.hide('79426d8d', 3);
      await store.unhide('79426d8d', 3);
      await store.unhide('79426d8d', 3);
      final loaded = await store.load('79426d8d');
      expect(loaded.hiddenChannelIndices, isEmpty);
    });

    test(
      'muted and hidden coexist independently (mute does not hide)',
      () async {
        final store = MeshCoreChannelPrefsStore();
        await store.mute('79426d8d', 1);
        await store.hide('79426d8d', 2);
        final loaded = await store.load('79426d8d');
        expect(loaded.mutedChannelIndices, equals({1}));
        expect(loaded.hiddenChannelIndices, equals({2}));
      },
    );

    test('muting a channel does not affect the hidden set', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.hide('79426d8d', 1);
      await store.mute('79426d8d', 1);
      final loaded = await store.load('79426d8d');
      expect(loaded.mutedChannelIndices, equals({1}));
      expect(
        loaded.hiddenChannelIndices,
        equals({1}),
        reason: 'hidden set must be preserved when the same idx is muted',
      );
    });

    test('hiding a channel does not affect the muted set', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.mute('79426d8d', 1);
      await store.hide('79426d8d', 1);
      final loaded = await store.load('79426d8d');
      expect(loaded.mutedChannelIndices, equals({1}));
      expect(loaded.hiddenChannelIndices, equals({1}));
    });

    test('two devices keep independent hidden sets', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.hide('aaaaaaaa', 1);
      await store.hide('bbbbbbbb', 2);
      final a = await store.load('aaaaaaaa');
      final b = await store.load('bbbbbbbb');
      expect(a.hiddenChannelIndices, equals({1}));
      expect(b.hiddenChannelIndices, equals({2}));
    });

    test('clear() removes hidden too (not just muted)', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.mute('79426d8d', 1);
      await store.hide('79426d8d', 2);
      await store.clear('79426d8d');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('meshcore_channel_prefs_79426d8d'), isFalse);
      final loaded = await store.load('79426d8d');
      expect(loaded.mutedChannelIndices, isEmpty);
      expect(loaded.hiddenChannelIndices, isEmpty);
    });

    test(
      'corrupt JSON returns empty prefs (no throw, no auto-purge)',
      () async {
        SharedPreferences.setMockInitialValues({
          'meshcore_channel_prefs_79426d8d': '{ "muted": [1], "hidden":',
        });
        final store = MeshCoreChannelPrefsStore();
        final loaded = await store.load('79426d8d');
        expect(loaded.mutedChannelIndices, isEmpty);
        expect(loaded.hiddenChannelIndices, isEmpty);
        // Corrupt blob must remain on disk (D37-A invariant).
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('meshcore_channel_prefs_79426d8d'), isTrue);
      },
    );

    test('empty device-key is a no-op for hide / unhide', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.hide('79426d8d', 3);
      await store.hide('', 9);
      await store.unhide('', 3);
      final loaded = await store.load('79426d8d');
      expect(loaded.hiddenChannelIndices, equals({3}));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('meshcore_channel_prefs_'), isFalse);
    });

    test('persisted blob contains hidden indices but no PSK / code / '
        'channel name', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.hide('79426d8d', 0);
      await store.hide('79426d8d', 5);
      final prefs = await SharedPreferences.getInstance();
      final blob = prefs.getString('meshcore_channel_prefs_79426d8d')!;
      final pskShape = RegExp(r'[0-9a-fA-F]{32}');
      final channelCodeShape = RegExp(r'[A-Za-z0-9#_-]+:[0-9a-fA-F]{32}');
      expect(pskShape.hasMatch(blob), isFalse);
      expect(channelCodeShape.hasMatch(blob), isFalse);
      final decoded = jsonDecode(blob) as Map<String, dynamic>;
      expect(decoded['hidden'], orderedEquals([0, 5]));
    });
  });
}
