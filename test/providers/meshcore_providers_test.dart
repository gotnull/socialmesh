// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/models/meshcore_channel.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MeshCoreContactsNotifier', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(meshCoreContactsProvider);
      expect(state.contacts, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('addContact adds new contact', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(meshCoreContactsProvider.notifier);
      final contact = MeshCoreContact(
        publicKey: Uint8List.fromList(List.generate(32, (i) => i)),
        name: 'TestContact',
        type: MeshCoreAdvType.chat,
        pathLength: 1,
        path: Uint8List.fromList([0x01]),
        lastSeen: DateTime.now(),
      );

      notifier.addContact(contact);

      final state = container.read(meshCoreContactsProvider);
      expect(state.contacts.length, equals(1));
      expect(state.contacts[0].name, equals('TestContact'));
    });

    test('addContact updates existing contact by publicKey', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(meshCoreContactsProvider.notifier);
      final publicKey = Uint8List.fromList(List.generate(32, (i) => i));

      notifier.addContact(
        MeshCoreContact(
          publicKey: publicKey,
          name: 'Original',
          type: MeshCoreAdvType.chat,
          pathLength: 1,
          path: Uint8List.fromList([0x01]),
          lastSeen: DateTime.now(),
        ),
      );

      notifier.addContact(
        MeshCoreContact(
          publicKey: publicKey,
          name: 'Updated',
          type: MeshCoreAdvType.repeater,
          pathLength: 2,
          path: Uint8List.fromList([0x01, 0x02]),
          lastSeen: DateTime.now(),
        ),
      );

      final state = container.read(meshCoreContactsProvider);
      expect(state.contacts.length, equals(1));
      expect(state.contacts[0].name, equals('Updated'));
      expect(state.contacts[0].type, equals(MeshCoreAdvType.repeater));
    });

    test('addContact maintains alphabetical order', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(meshCoreContactsProvider.notifier);

      notifier.addContact(
        MeshCoreContact(
          publicKey: Uint8List.fromList(List.generate(32, (_) => 0xCC)),
          name: 'Zeta',
          type: MeshCoreAdvType.chat,
          pathLength: 1,
          path: Uint8List.fromList([0x01]),
          lastSeen: DateTime.now(),
        ),
      );

      notifier.addContact(
        MeshCoreContact(
          publicKey: Uint8List.fromList(List.generate(32, (_) => 0xAA)),
          name: 'Alpha',
          type: MeshCoreAdvType.chat,
          pathLength: 1,
          path: Uint8List.fromList([0x01]),
          lastSeen: DateTime.now(),
        ),
      );

      notifier.addContact(
        MeshCoreContact(
          publicKey: Uint8List.fromList(List.generate(32, (_) => 0xBB)),
          name: 'Beta',
          type: MeshCoreAdvType.chat,
          pathLength: 1,
          path: Uint8List.fromList([0x01]),
          lastSeen: DateTime.now(),
        ),
      );

      final contacts = container.read(meshCoreContactsProvider).contacts;
      expect(contacts[0].name, equals('Alpha'));
      expect(contacts[1].name, equals('Beta'));
      expect(contacts[2].name, equals('Zeta'));
    });

    test('removeContact removes contact', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(meshCoreContactsProvider.notifier);
      final contact = MeshCoreContact(
        publicKey: Uint8List.fromList(List.generate(32, (i) => i)),
        name: 'ToRemove',
        type: MeshCoreAdvType.chat,
        pathLength: 1,
        path: Uint8List.fromList([0x01]),
        lastSeen: DateTime.now(),
      );

      notifier.addContact(contact);
      expect(
        container.read(meshCoreContactsProvider).contacts.length,
        equals(1),
      );

      notifier.removeContact(contact.publicKeyHex);
      expect(
        container.read(meshCoreContactsProvider).contacts.length,
        equals(0),
      );
    });

    test('updateUnreadCount updates specific contact', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(meshCoreContactsProvider.notifier);
      final contact = MeshCoreContact(
        publicKey: Uint8List.fromList(List.generate(32, (i) => i)),
        name: 'Test',
        type: MeshCoreAdvType.chat,
        pathLength: 1,
        path: Uint8List.fromList([0x01]),
        lastSeen: DateTime.now(),
        unreadCount: 0,
      );

      notifier.addContact(contact);
      notifier.updateUnreadCount(contact.publicKeyHex, 5);

      final updated = container.read(meshCoreContactsProvider).contacts[0];
      expect(updated.unreadCount, equals(5));
    });

    test('clearUnread sets count to 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(meshCoreContactsProvider.notifier);
      final contact = MeshCoreContact(
        publicKey: Uint8List.fromList(List.generate(32, (i) => i)),
        name: 'Test',
        type: MeshCoreAdvType.chat,
        pathLength: 1,
        path: Uint8List.fromList([0x01]),
        lastSeen: DateTime.now(),
        unreadCount: 10,
      );

      notifier.addContact(contact);
      notifier.clearUnread(contact.publicKeyHex);

      final updated = container.read(meshCoreContactsProvider).contacts[0];
      expect(updated.unreadCount, equals(0));
    });
  });

  group('MeshCoreChannelsNotifier', () {
    test('initial state is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(meshCoreChannelsProvider);
      expect(state.channels, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });
  });

  group('MeshCoreSelfInfoState', () {
    test('initial state has null selfInfo', () {
      const state = MeshCoreSelfInfoState.initial();
      expect(state.selfInfo, isNull);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('loading state has isLoading true', () {
      const state = MeshCoreSelfInfoState.loading();
      expect(state.selfInfo, isNull);
      expect(state.isLoading, isTrue);
      expect(state.error, isNull);
    });

    test('failed state has error message', () {
      final state = MeshCoreSelfInfoState.failed('Connection error');
      expect(state.selfInfo, isNull);
      expect(state.isLoading, isFalse);
      expect(state.error, equals('Connection error'));
    });
  });

  group('MeshCoreContactsState', () {
    test('initial state is empty', () {
      const state = MeshCoreContactsState.initial();
      expect(state.contacts, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.lastRefresh, isNull);
    });

    test('loading state has isLoading true', () {
      const state = MeshCoreContactsState.loading();
      expect(state.contacts, isEmpty);
      expect(state.isLoading, isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      final contacts = <MeshCoreContact>[
        MeshCoreContact(
          publicKey: Uint8List.fromList(List.generate(32, (i) => i)),
          name: 'Test',
          type: MeshCoreAdvType.chat,
          pathLength: 1,
          path: Uint8List.fromList([0x01]),
          lastSeen: DateTime.now(),
        ),
      ];
      final state = MeshCoreContactsState(
        contacts: contacts,
        isLoading: false,
        lastRefresh: DateTime(2024, 1, 1),
      );

      final updated = state.copyWith(isLoading: true);

      expect(updated.contacts.length, equals(1));
      expect(updated.isLoading, isTrue);
      expect(updated.lastRefresh, equals(DateTime(2024, 1, 1)));
    });
  });

  group('MeshCoreChannelsState', () {
    test('initial state is empty', () {
      const state = MeshCoreChannelsState.initial();
      expect(state.channels, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      final channels = <MeshCoreChannel>[
        MeshCoreChannel(index: 0, name: 'Test', psk: Uint8List(16)),
      ];
      final state = MeshCoreChannelsState(
        channels: channels,
        isLoading: false,
        lastRefresh: DateTime(2024, 1, 1),
      );

      final updated = state.copyWith(isLoading: true);

      expect(updated.channels.length, equals(1));
      expect(updated.isLoading, isTrue);
      expect(updated.lastRefresh, equals(DateTime(2024, 1, 1)));
    });
  });
}
