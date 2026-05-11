// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D38-A - per-channel unread persistence on `MeshCoreContactStore`.
//
// Pins:
//   - incrementChannelUnreadCount() increments from 0 and returns the
//     new value.
//   - getChannelUnreadCount() reads the persisted count; missing key
//     returns 0.
//   - clearChannelUnreadCount() zeroes the count (and removes the key
//     so the SharedPreferences keyspace stays compact).
//   - Corrupt value (wrong type at the key) returns 0 without
//     throwing.
//   - Keys are device-scoped: two devices keep independent counts
//     even for the same slot index.
//   - Key shape uses the slot index ONLY - never the name / PSK /
//     channel code / full key / full pubkey.
//   - Slot-reuse inheritance is intentional (matches D37-A/B/C slot-
//     identity semantics).
//   - clearAll() removes channel-unread keys alongside contact-unread
//     keys.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_contact_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MeshCoreContactStore channel-unread API', () {
    test('incrementChannelUnreadCount() increments from 0', () async {
      final store = MeshCoreContactStore();
      expect(await store.incrementChannelUnreadCount('79426d8d', 3), 1);
      expect(await store.incrementChannelUnreadCount('79426d8d', 3), 2);
      expect(await store.incrementChannelUnreadCount('79426d8d', 3), 3);
    });

    test('getChannelUnreadCount() returns the persisted count', () async {
      final store = MeshCoreContactStore();
      await store.incrementChannelUnreadCount('79426d8d', 3);
      await store.incrementChannelUnreadCount('79426d8d', 3);
      expect(await store.getChannelUnreadCount('79426d8d', 3), 2);
    });

    test('getChannelUnreadCount() on a missing key returns 0', () async {
      final store = MeshCoreContactStore();
      expect(await store.getChannelUnreadCount('79426d8d', 9), 0);
    });

    test('clearChannelUnreadCount() zeroes the persisted count', () async {
      final store = MeshCoreContactStore();
      await store.incrementChannelUnreadCount('79426d8d', 3);
      await store.incrementChannelUnreadCount('79426d8d', 3);
      await store.clearChannelUnreadCount('79426d8d', 3);
      expect(await store.getChannelUnreadCount('79426d8d', 3), 0);
    });

    test('setting count <= 0 removes the on-disk key', () async {
      final store = MeshCoreContactStore();
      await store.setChannelUnreadCount('79426d8d', 3, 5);
      await store.setChannelUnreadCount('79426d8d', 3, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey('meshcore_channel_unread_79426d8d_3'),
        isFalse,
        reason: 'zero count should leave the keyspace compact',
      );
    });

    test('corrupt value (wrong type) returns 0 without throwing', () async {
      SharedPreferences.setMockInitialValues({
        // String written where an int is expected (simulating an
        // older-build serialisation).
        'meshcore_channel_unread_79426d8d_3': 'not-an-int',
      });
      final store = MeshCoreContactStore();
      expect(await store.getChannelUnreadCount('79426d8d', 3), 0);
    });

    test('empty device-prefix is a no-op (no key materialises)', () async {
      final store = MeshCoreContactStore();
      // No-pubkey path: writes must not land in the global keyspace.
      await store.incrementChannelUnreadCount('', 3);
      await store.setChannelUnreadCount('', 3, 9);
      await store.clearChannelUnreadCount('', 3);
      expect(await store.getChannelUnreadCount('', 3), 0);
      final prefs = await SharedPreferences.getInstance();
      final ours = prefs.getKeys().where(
        (k) => k.startsWith('meshcore_channel_unread_'),
      );
      expect(ours, isEmpty);
    });

    test('keys are device-scoped (two devices, same slot)', () async {
      final store = MeshCoreContactStore();
      await store.incrementChannelUnreadCount('aaaaaaaa', 3);
      await store.incrementChannelUnreadCount('bbbbbbbb', 3);
      await store.incrementChannelUnreadCount('bbbbbbbb', 3);
      expect(await store.getChannelUnreadCount('aaaaaaaa', 3), 1);
      expect(await store.getChannelUnreadCount('bbbbbbbb', 3), 2);
    });

    test('keys use slot index ONLY - no name / PSK / code material', () async {
      final store = MeshCoreContactStore();
      await store.incrementChannelUnreadCount('79426d8d', 0);
      await store.incrementChannelUnreadCount('79426d8d', 7);
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs
              .getKeys()
              .where((k) => k.startsWith('meshcore_channel_unread_'))
              .toList()
            ..sort();
      expect(
        keys,
        orderedEquals([
          'meshcore_channel_unread_79426d8d_0',
          'meshcore_channel_unread_79426d8d_7',
        ]),
      );

      // Redaction sweep on the keyspace + values.
      final pskShape = RegExp(r'[0-9a-fA-F]{32}');
      final channelCodeShape = RegExp(r'[A-Za-z0-9#_-]+:[0-9a-fA-F]{32}');
      for (final key in keys) {
        expect(pskShape.hasMatch(key), isFalse);
        expect(channelCodeShape.hasMatch(key), isFalse);
        final raw = prefs.get(key);
        // Values are ints, never strings carrying message text.
        expect(raw, isA<int>());
      }
    });

    test(
      'slot-reuse inheritance is intentional (slot is the identity)',
      () async {
        // D37-A/B/C established that slot index is the identity. D38-A
        // follows the same convention: deleting a channel and creating
        // a new channel at the same slot index inherits the unread
        // count. Pin this so a future maintainer doesn't "fix" it
        // unprompted.
        final store = MeshCoreContactStore();
        await store.incrementChannelUnreadCount('79426d8d', 3);
        await store.incrementChannelUnreadCount('79426d8d', 3);
        // Simulate a "delete and re-create" by NOT clearing the unread.
        expect(
          await store.getChannelUnreadCount('79426d8d', 3),
          2,
          reason: 'slot-reuse intentionally inherits the existing unread',
        );
      },
    );

    test(
      'clearAll() wipes channel-unread keys alongside contact unread',
      () async {
        final store = MeshCoreContactStore();
        await store.incrementChannelUnreadCount('79426d8d', 3);
        await store.setUnreadCount('CONTACTAA', 4);
        await store.clearAll();
        expect(await store.getChannelUnreadCount('79426d8d', 3), 0);
        expect(await store.getUnreadCount('CONTACTAA'), 0);
        final prefs = await SharedPreferences.getInstance();
        final ours = prefs.getKeys().where(
          (k) =>
              k.startsWith('meshcore_channel_unread_') ||
              k.startsWith('meshcore_unread_'),
        );
        expect(ours, isEmpty);
      },
    );

    test(
      'contact-side unread API is unaffected by channel API usage',
      () async {
        final store = MeshCoreContactStore();
        await store.incrementChannelUnreadCount('79426d8d', 3);
        await store.incrementChannelUnreadCount('79426d8d', 3);
        // Contact-side getter must return 0 (no contact unread set).
        expect(await store.getUnreadCount('CONTACTAA'), 0);
        // Contact-side setter still works.
        await store.setUnreadCount('CONTACTAA', 5);
        expect(await store.getUnreadCount('CONTACTAA'), 5);
        // Channel count is preserved across contact-side activity.
        expect(await store.getChannelUnreadCount('79426d8d', 3), 2);
      },
    );
  });
}
