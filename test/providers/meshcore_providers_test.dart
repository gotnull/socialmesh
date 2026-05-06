// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

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

      notifier.addContactLocal(contact);

      final state = container.read(meshCoreContactsProvider);
      expect(state.contacts.length, equals(1));
      expect(state.contacts[0].name, equals('TestContact'));
    });

    test('addContact updates existing contact by publicKey', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(meshCoreContactsProvider.notifier);
      final publicKey = Uint8List.fromList(List.generate(32, (i) => i));

      notifier.addContactLocal(
        MeshCoreContact(
          publicKey: publicKey,
          name: 'Original',
          type: MeshCoreAdvType.chat,
          pathLength: 1,
          path: Uint8List.fromList([0x01]),
          lastSeen: DateTime.now(),
        ),
      );

      notifier.addContactLocal(
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

      notifier.addContactLocal(
        MeshCoreContact(
          publicKey: Uint8List.fromList(List.generate(32, (_) => 0xCC)),
          name: 'Zeta',
          type: MeshCoreAdvType.chat,
          pathLength: 1,
          path: Uint8List.fromList([0x01]),
          lastSeen: DateTime.now(),
        ),
      );

      notifier.addContactLocal(
        MeshCoreContact(
          publicKey: Uint8List.fromList(List.generate(32, (_) => 0xAA)),
          name: 'Alpha',
          type: MeshCoreAdvType.chat,
          pathLength: 1,
          path: Uint8List.fromList([0x01]),
          lastSeen: DateTime.now(),
        ),
      );

      notifier.addContactLocal(
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

      notifier.addContactLocal(contact);
      expect(
        container.read(meshCoreContactsProvider).contacts.length,
        equals(1),
      );

      notifier.removeContactLocal(contact.publicKeyHex);
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

      notifier.addContactLocal(contact);
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

      notifier.addContactLocal(contact);
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

  group('MeshCoreShowBatteryVoltageNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('default value is false when nothing has been saved', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // build() returns false synchronously, then schedules a microtask
      // to read from prefs. Pump once so the microtask completes before
      // we assert.
      expect(container.read(meshCoreShowBatteryVoltageProvider), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(meshCoreShowBatteryVoltageProvider), isFalse);
    });

    test('cold-start hydrates from previously saved value', () async {
      SharedPreferences.setMockInitialValues({
        kMeshCoreShowBatteryVoltagePrefKey: true,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Touch the provider so build() runs, then let the microtask fire.
      container.read(meshCoreShowBatteryVoltageProvider);
      // Drain microtask + setBool's async write callback.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(meshCoreShowBatteryVoltageProvider),
        isTrue,
        reason: 'cold-start must rehydrate the persisted preference',
      );
    });

    test('set(true) persists and surfaces immediately', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        meshCoreShowBatteryVoltageProvider.notifier,
      );
      await notifier.set(true);
      expect(container.read(meshCoreShowBatteryVoltageProvider), isTrue);

      // A fresh container reading from the same SharedPreferences must
      // see the persisted value (cold-restart simulation).
      final restarted = ProviderContainer();
      addTearDown(restarted.dispose);
      restarted.read(meshCoreShowBatteryVoltageProvider);
      await Future<void>.delayed(Duration.zero);
      expect(restarted.read(meshCoreShowBatteryVoltageProvider), isTrue);
    });

    test('set(false) clears the preference back to default', () async {
      SharedPreferences.setMockInitialValues({
        kMeshCoreShowBatteryVoltagePrefKey: true,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Trigger build then drain the hydration microtask before asserting.
      container.read(meshCoreShowBatteryVoltageProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(meshCoreShowBatteryVoltageProvider), isTrue);

      await container
          .read(meshCoreShowBatteryVoltageProvider.notifier)
          .set(false);
      expect(container.read(meshCoreShowBatteryVoltageProvider), isFalse);

      final restarted = ProviderContainer();
      addTearDown(restarted.dispose);
      restarted.read(meshCoreShowBatteryVoltageProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(restarted.read(meshCoreShowBatteryVoltageProvider), isFalse);
    });

    test('set(same) is a no-op', () async {
      // Performance + observability hygiene: setting the same value
      // should not trigger a reactive rebuild or a redundant write.
      SharedPreferences.setMockInitialValues({
        kMeshCoreShowBatteryVoltagePrefKey: true,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Force build() to run and the cold-start hydration microtask to
      // complete BEFORE attaching the listener, otherwise the
      // false-then-true transition from cold-start would itself count
      // as a rebuild and the assertion below would race the microtask.
      container.read(meshCoreShowBatteryVoltageProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(meshCoreShowBatteryVoltageProvider), isTrue);

      var rebuildCount = 0;
      container.listen<bool>(
        meshCoreShowBatteryVoltageProvider,
        (_, _) => rebuildCount++,
      );

      await container
          .read(meshCoreShowBatteryVoltageProvider.notifier)
          .set(true); // already true
      expect(rebuildCount, equals(0));
    });
  });
}
