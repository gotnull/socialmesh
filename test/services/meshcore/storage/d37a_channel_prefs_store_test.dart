// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D37-A - MeshCoreChannelPrefsStore tests.
//
// Pins:
//   - Missing key returns empty prefs, never throws.
//   - mute / unmute / save / load round-trip the muted set verbatim.
//   - Repeated mute / unmute are idempotent.
//   - `hidden` and `order` round-trip as empty arrays (reserved for
//     D37-B / D37-C; D37-A must not strip them from the on-disk JSON).
//   - Corrupt JSON returns empty prefs without throwing AND does not
//     auto-delete the bad blob (so a parser-side fix later could
//     potentially recover).
//   - `clear()` removes the on-disk key.
//   - Storage key is the per-device prefix only - never the PSK, never
//     the channel code, never the channel name.
//   - Empty device-key is a no-op (load returns empty; save/mute/unmute
//     never write to SharedPreferences).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_channel_prefs_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MeshCoreChannelPrefs toJson/fromJson', () {
    test('round-trips a populated muted set', () {
      const original = MeshCoreChannelPrefs(mutedChannelIndices: {0, 3, 7});
      final restored = MeshCoreChannelPrefs.fromJson(original.toJson());
      expect(restored.mutedChannelIndices, equals({0, 3, 7}));
      expect(restored.hiddenChannelIndices, isEmpty);
      expect(restored.orderedChannelIndices, isEmpty);
    });

    test('writes muted as a sorted list', () {
      const original = MeshCoreChannelPrefs(mutedChannelIndices: {7, 0, 3});
      final json = original.toJson();
      expect(json['muted'], orderedEquals([0, 3, 7]));
    });

    test('rejects out-of-range integers on decode', () {
      final restored = MeshCoreChannelPrefs.fromJson(<String, dynamic>{
        'muted': [0, -1, 999, 3, 'oops'],
        'hidden': [],
        'order': [],
      });
      expect(restored.mutedChannelIndices, equals({0, 3}));
    });

    test('reserved hidden / order arrays survive a JSON round-trip', () {
      // D37-A only consumes `muted`. The on-disk shape must keep
      // `hidden` and `order` so D37-B / D37-C don't have to migrate.
      const original = MeshCoreChannelPrefs(mutedChannelIndices: {2});
      final json = jsonEncode(original.toJson());
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded.containsKey('hidden'), isTrue);
      expect(decoded.containsKey('order'), isTrue);
      expect(decoded['hidden'], isA<List>());
      expect(decoded['order'], isA<List>());
    });
  });

  group('MeshCoreChannelPrefsStore', () {
    test('load on a missing key returns the empty prefs', () async {
      final store = MeshCoreChannelPrefsStore();
      final loaded = await store.load('79426d8d');
      expect(loaded, equals(MeshCoreChannelPrefs.empty));
    });

    test('save then load round-trips a populated set', () async {
      final store = MeshCoreChannelPrefsStore();
      const prefs = MeshCoreChannelPrefs(mutedChannelIndices: {0, 5});
      await store.save('79426d8d', prefs);
      final loaded = await store.load('79426d8d');
      expect(loaded.mutedChannelIndices, equals({0, 5}));
    });

    test('mute() is idempotent', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.mute('79426d8d', 3);
      await store.mute('79426d8d', 3);
      final loaded = await store.load('79426d8d');
      expect(loaded.mutedChannelIndices, equals({3}));
    });

    test('unmute() is idempotent', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.mute('79426d8d', 3);
      await store.unmute('79426d8d', 3);
      await store.unmute('79426d8d', 3);
      final loaded = await store.load('79426d8d');
      expect(loaded.mutedChannelIndices, isEmpty);
    });

    test('two devices keep independent prefs', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.mute('aaaaaaaa', 1);
      await store.mute('bbbbbbbb', 2);
      final a = await store.load('aaaaaaaa');
      final b = await store.load('bbbbbbbb');
      expect(a.mutedChannelIndices, equals({1}));
      expect(b.mutedChannelIndices, equals({2}));
    });

    test('corrupt JSON returns empty prefs without throwing', () async {
      SharedPreferences.setMockInitialValues({
        'meshcore_channel_prefs_79426d8d': '{ not valid json',
      });
      final store = MeshCoreChannelPrefsStore();
      final loaded = await store.load('79426d8d');
      expect(loaded, equals(MeshCoreChannelPrefs.empty));
    });

    test('corrupt JSON is NOT auto-deleted on load', () async {
      SharedPreferences.setMockInitialValues({
        'meshcore_channel_prefs_79426d8d': '{ not valid json',
      });
      final store = MeshCoreChannelPrefsStore();
      await store.load('79426d8d');
      // The raw blob must still be on disk - a future parser-side fix
      // could recover the data; auto-erasing is silent data loss.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey('meshcore_channel_prefs_79426d8d'),
        isTrue,
        reason: 'corrupt blob must not be auto-purged on load',
      );
    });

    test('non-object JSON returns empty prefs', () async {
      SharedPreferences.setMockInitialValues({
        'meshcore_channel_prefs_79426d8d': '[1, 2, 3]',
      });
      final store = MeshCoreChannelPrefsStore();
      final loaded = await store.load('79426d8d');
      expect(loaded, equals(MeshCoreChannelPrefs.empty));
    });

    test('clear() removes the on-disk key', () async {
      final store = MeshCoreChannelPrefsStore();
      await store.mute('79426d8d', 1);
      await store.clear('79426d8d');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('meshcore_channel_prefs_79426d8d'), isFalse);
    });

    test(
      'empty device-key is a no-op for load / save / mute / unmute',
      () async {
        final store = MeshCoreChannelPrefsStore();
        // Pre-seed something for another device so we'd notice cross-talk.
        await store.mute('79426d8d', 1);
        // All calls below with the empty key must NOT touch SharedPrefs.
        final loaded = await store.load('');
        await store.save(
          '',
          const MeshCoreChannelPrefs(mutedChannelIndices: {9}),
        );
        await store.mute('', 9);
        await store.unmute('', 9);
        await store.clear('');
        expect(loaded, equals(MeshCoreChannelPrefs.empty));
        // The seeded entry must still be untouched.
        final unchanged = await store.load('79426d8d');
        expect(unchanged.mutedChannelIndices, equals({1}));
        final prefs = await SharedPreferences.getInstance();
        // No global key materialised under the empty-string form.
        expect(prefs.containsKey('meshcore_channel_prefs_'), isFalse);
      },
    );

    test('on-disk key uses the device prefix only - no PSK / name / '
        'channel-code material appears in the keyspace', () async {
      // Set up a scenario that would tempt a careless implementer to
      // key by channel name or PSK.
      final store = MeshCoreChannelPrefsStore();
      await store.mute('79426d8d', 0);
      await store.mute('79426d8d', 5);

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      // Exactly one channel-prefs key for this device.
      final ours = keys
          .where((k) => k.startsWith('meshcore_channel_prefs_'))
          .toList();
      expect(ours, hasLength(1));
      expect(ours.single, equals('meshcore_channel_prefs_79426d8d'));

      // The persisted blob carries the int slot indices and nothing
      // resembling a name, PSK, or channel-code.
      final blob = prefs.getString(ours.single)!;
      // Must NOT contain hex strings of PSK length (32 chars).
      final pskShapedHex = RegExp(r'[0-9a-fA-F]{32}');
      expect(
        pskShapedHex.hasMatch(blob),
        isFalse,
        reason: 'blob must not embed a 32-char hex PSK',
      );
      // Must NOT contain a `name:32hex` channel-code shape. JSON itself
      // has `:` separators everywhere, so anchor on the channel-code
      // structure instead of a bare colon.
      final channelCodeShape = RegExp(r'[A-Za-z0-9#_-]+:[0-9a-fA-F]{32}');
      expect(
        channelCodeShape.hasMatch(blob),
        isFalse,
        reason: 'blob must not embed a name:hex channel code',
      );
      // Must contain the muted indices verbatim.
      final decoded = jsonDecode(blob) as Map<String, dynamic>;
      expect(decoded['muted'], orderedEquals([0, 5]));
    });

    test('test injection via constructor works (no global override '
        'needed)', () async {
      // Tests must be able to swap in their own SharedPreferences.
      final prefs = await SharedPreferences.getInstance();
      final store = MeshCoreChannelPrefsStore(preferences: prefs);
      await store.mute('79426d8d', 4);
      final loaded = await store.load('79426d8d');
      expect(loaded.mutedChannelIndices, equals({4}));
    });
  });
}
