// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
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

    group('contact persistence', () {
      test('saves and loads contacts', () async {
        final contact = MeshCoreContact(
          publicKey: Uint8List.fromList(List.generate(32, (i) => i)),
          name: 'TestNode',
          type: MeshCoreAdvType.chat,
          pathLength: 2,
          path: Uint8List.fromList([0x01, 0x02]),
          lastSeen: DateTime.now(),
        );

        await store.saveContact(contact);

        final loaded = await store.loadContacts();
        expect(loaded.length, equals(1));
        expect(loaded[0].name, equals('TestNode'));
        expect(loaded[0].type, equals(MeshCoreAdvType.chat));
        expect(loaded[0].pathLength, equals(2));
      });

      test('updates existing contact by publicKey', () async {
        final publicKey = Uint8List.fromList(List.generate(32, (i) => i));
        final contact = MeshCoreContact(
          publicKey: publicKey,
          name: 'OriginalName',
          type: MeshCoreAdvType.chat,
          pathLength: 1,
          path: Uint8List.fromList([0x01]),
          lastSeen: DateTime.now(),
        );

        await store.saveContact(contact);

        final updated = contact.copyWith(
          name: 'UpdatedName',
          type: MeshCoreAdvType.repeater,
        );
        await store.saveContact(updated);

        final loaded = await store.loadContacts();
        expect(loaded.length, equals(1));
        expect(loaded[0].name, equals('UpdatedName'));
        expect(loaded[0].type, equals(MeshCoreAdvType.repeater));
      });

      test('saves multiple contacts', () async {
        for (int i = 0; i < 5; i++) {
          final contact = MeshCoreContact(
            publicKey: Uint8List.fromList(List.generate(32, (_) => i)),
            name: 'Node$i',
            type: MeshCoreAdvType.chat,
            pathLength: 1,
            path: Uint8List.fromList([i]),
            lastSeen: DateTime.now(),
          );
          await store.saveContact(contact);
        }

        final loaded = await store.loadContacts();
        expect(loaded.length, equals(5));
      });

      test('removes contact', () async {
        final contact = MeshCoreContact(
          publicKey: Uint8List.fromList(List.generate(32, (i) => i)),
          name: 'ToDelete',
          type: MeshCoreAdvType.chat,
          pathLength: 1,
          path: Uint8List.fromList([0x01]),
          lastSeen: DateTime.now(),
        );

        await store.saveContact(contact);
        expect((await store.loadContacts()).length, equals(1));

        await store.removeContact(contact.publicKeyHex);
        expect((await store.loadContacts()).length, equals(0));
      });

      test('clearAll removes all contacts', () async {
        for (int i = 0; i < 3; i++) {
          await store.saveContact(
            MeshCoreContact(
              publicKey: Uint8List.fromList(List.generate(32, (_) => i)),
              name: 'Node$i',
              type: MeshCoreAdvType.chat,
              pathLength: 1,
              path: Uint8List.fromList([i]),
              lastSeen: DateTime.now(),
            ),
          );
        }

        expect((await store.loadContacts()).length, equals(3));

        await store.clearAll();

        expect((await store.loadContacts()).length, equals(0));
      });
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

      test('removeContact also clears unread count', () async {
        final publicKey = Uint8List.fromList(List.generate(32, (i) => i));
        final contact = MeshCoreContact(
          publicKey: publicKey,
          name: 'Test',
          type: MeshCoreAdvType.chat,
          pathLength: 1,
          path: Uint8List.fromList([0x01]),
          lastSeen: DateTime.now(),
        );

        await store.saveContact(contact);
        await store.setUnreadCount(contact.publicKeyHex, 5);
        expect(await store.getUnreadCount(contact.publicKeyHex), equals(5));

        await store.removeContact(contact.publicKeyHex);
        expect(await store.getUnreadCount(contact.publicKeyHex), equals(0));
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

      test('loadContacts includes unread counts', () async {
        final publicKey = Uint8List.fromList(List.generate(32, (i) => i));
        final contact = MeshCoreContact(
          publicKey: publicKey,
          name: 'Test',
          type: MeshCoreAdvType.chat,
          pathLength: 1,
          path: Uint8List.fromList([0x01]),
          lastSeen: DateTime.now(),
        );

        await store.saveContact(contact);
        await store.setUnreadCount(contact.publicKeyHex, 7);

        final loaded = await store.loadContacts();
        expect(loaded[0].unreadCount, equals(7));
      });
    });

    group('contact serialization', () {
      test('serializes all contact fields', () async {
        final contact = MeshCoreContact(
          publicKey: Uint8List.fromList(List.generate(32, (i) => i)),
          name: 'FullContact',
          type: MeshCoreAdvType.repeater,
          pathLength: 3,
          path: Uint8List.fromList([0x01, 0x02, 0x03]),
          pathOverride: -1,
          pathOverrideBytes: Uint8List.fromList([0xFF]),
          latitude: 37.7749,
          longitude: -122.4194,
          lastSeen: DateTime(2024, 1, 15, 10, 30),
          lastMessageAt: DateTime(2024, 1, 15, 10, 35),
        );

        await store.saveContact(contact);
        final loaded = (await store.loadContacts())[0];

        expect(loaded.name, equals('FullContact'));
        expect(loaded.type, equals(MeshCoreAdvType.repeater));
        expect(loaded.pathLength, equals(3));
        expect(loaded.path, equals(Uint8List.fromList([0x01, 0x02, 0x03])));
        expect(loaded.pathOverride, equals(-1));
        expect(loaded.pathOverrideBytes, equals(Uint8List.fromList([0xFF])));
        expect(loaded.latitude, equals(37.7749));
        expect(loaded.longitude, equals(-122.4194));
        expect(loaded.lastSeen, equals(DateTime(2024, 1, 15, 10, 30)));
        expect(loaded.lastMessageAt, equals(DateTime(2024, 1, 15, 10, 35)));
      });

      test('handles missing optional fields gracefully', () async {
        final contact = MeshCoreContact(
          publicKey: Uint8List.fromList(List.generate(32, (i) => i)),
          name: 'MinimalContact',
          type: MeshCoreAdvType.chat,
          pathLength: 0,
          path: Uint8List(0),
          lastSeen: DateTime.now(),
        );

        await store.saveContact(contact);
        final loaded = (await store.loadContacts())[0];

        expect(loaded.name, equals('MinimalContact'));
        expect(loaded.pathOverride, isNull);
        expect(loaded.pathOverrideBytes, isNull);
      });
    });

    group('initialization', () {
      test('loadContacts auto-initializes', () async {
        // Even without explicit init(), loadContacts should work
        final newStore = MeshCoreContactStore();
        final contacts = await newStore.loadContacts();
        expect(contacts, isEmpty);
      });

      test('init is idempotent', () async {
        final newStore = MeshCoreContactStore();
        await newStore.init();
        await newStore.init(); // Second call should not throw
        final contacts = await newStore.loadContacts();
        expect(contacts, isEmpty);
      });
    });
  });
}
