// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/radio_scope.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_contact_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MeshCoreContactStore', () {
    late MeshCoreContactStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = MeshCoreContactStore();
      await store.init();
    });

    group('unread counts', () {
      test('returns 0 for unknown contact', () async {
        final count = await store.getUnreadCount('nonexistent');
        expect(count, equals(0));
      });

      test('sets and gets unread count', () async {
        const keyHex = 'aabbccdd';
        await store.setUnreadCount(keyHex, 5);
        expect(await store.getUnreadCount(keyHex), equals(5));
      });

      test('increments unread count', () async {
        const keyHex = 'aabbccdd';
        expect(await store.incrementUnreadCount(keyHex), equals(1));
        expect(await store.incrementUnreadCount(keyHex), equals(2));
        expect(await store.incrementUnreadCount(keyHex), equals(3));
        expect(await store.getUnreadCount(keyHex), equals(3));
      });

      test('clears unread count', () async {
        const keyHex = 'aabbccdd';
        await store.setUnreadCount(keyHex, 10);
        await store.clearUnreadCount(keyHex);
        expect(await store.getUnreadCount(keyHex), equals(0));
      });

      test('setting count to 0 removes the entry', () async {
        const keyHex = 'aabbccdd';
        await store.setUnreadCount(keyHex, 5);
        await store.setUnreadCount(keyHex, 0);

        // Directly check SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('meshcore_unread_$keyHex'), isFalse);
      });

      test('clearAll clears all unread counts', () async {
        await store.setUnreadCount('key1', 5);
        await store.setUnreadCount('key2', 10);
        await store.setUnreadCount('key3', 15);

        await store.clearAll();

        expect(await store.getUnreadCount('key1'), equals(0));
        expect(await store.getUnreadCount('key2'), equals(0));
        expect(await store.getUnreadCount('key3'), equals(0));
      });
    });

    group('radio scope', () {
      test('unread counts are written under the radio scope', () async {
        await store.setUnreadCount('aabbccdd', 4);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getInt(
            RadioScope.instance.prefsKey('meshcore_unread_aabbccdd'),
          ),
          4,
        );
        expect(prefs.containsKey('meshcore_unread_aabbccdd'), isFalse);
        expect(await store.getUnreadCount('aabbccdd'), 4);
      });

      test('counts kept before scoping move into the scope once', () async {
        SharedPreferences.setMockInitialValues({
          'meshcore_unread_aabbccdd': 3,
          'meshcore_unread_11223344': 1,
          RadioScope.instance.prefsKey('meshcore_unread_11223344'): 7,
        });
        final fresh = MeshCoreContactStore();
        await fresh.adoptUnscopedUnreadCounts();

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getKeys().where((k) => k.startsWith('meshcore_unread_')),
          isEmpty,
        );
        expect(await fresh.getUnreadCount('aabbccdd'), 3);
        // A count the scope already had is kept.
        expect(await fresh.getUnreadCount('11223344'), 7);
      });
    });

    group('initialization', () {
      test('init is idempotent', () async {
        final newStore = MeshCoreContactStore();
        await newStore.init();
        await newStore.init(); // Second call should not throw
        expect(await newStore.getUnreadCount('aabbccdd'), 0);
      });

      test('clearAll removes the contact list older builds wrote', () async {
        SharedPreferences.setMockInitialValues({'meshcore_contacts': '[]'});
        final newStore = MeshCoreContactStore();
        await newStore.clearAll();
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('meshcore_contacts'), isFalse);
      });
    });
  });
}
