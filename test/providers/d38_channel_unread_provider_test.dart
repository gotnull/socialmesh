// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D38-A - `MeshCoreConversationsNotifier.markAsRead` for channels.
//
// Pinned invariants:
//   - markAsRead('channel_<idx>') clears the persisted per-channel
//     unread counter for the active device prefix.
//   - markAsRead on a malformed `channel_xyz` id does NOT throw; it
//     logs and returns.
//   - markAsRead with empty device prefix never writes to a global
//     SharedPreferences key.
//   - markAsRead('contact_pubkey') does NOT touch the channel-unread
//     keyspace (orthogonality with the contact path).
//
// Notes on test shape:
//   - We instantiate `MeshCoreConversationsNotifier` via a real
//     ProviderContainer (mirrors the D22 drain-heartbeat tests).
//   - We pre-seed disk via the public store API and observe the
//     persisted side effect; the in-memory state is independently
//     pinned by the rebuild tests.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/core/logging.dart';
import 'package:socialmesh/providers/meshcore_message_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_contact_store.dart';

class _FakeTransport implements MeshCoreTransport {
  final StreamController<Uint8List> _rx =
      StreamController<Uint8List>.broadcast();
  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;
  @override
  Future<void> sendRaw(Uint8List data) async {}
  @override
  bool get isConnected => true;
  Future<void> dispose() async {
    if (!_rx.isClosed) await _rx.close();
  }
}

ProviderContainer _container({
  required MeshCoreSession? session,
  required String pubKeyPrefix,
}) {
  return ProviderContainer(
    overrides: [
      meshCoreSessionProvider.overrideWithValue(session),
      meshCoreSelfPubKeyPrefixProvider.overrideWith((ref) => pubKeyPrefix),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeTransport transport;
  late MeshCoreSession session;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    transport = _FakeTransport();
    session = MeshCoreSession(transport);
    AppLogging.reset();
  });

  tearDown(() async {
    AppLogging.reset();
    await transport.dispose();
  });

  group('markAsRead for channels (D38-A)', () {
    test(
      'clears the persisted per-channel unread for the active device',
      () async {
        // Pre-seed disk via the store.
        final store = MeshCoreContactStore();
        await store.incrementChannelUnreadCount('79426d8d', 3);
        await store.incrementChannelUnreadCount('79426d8d', 3);
        expect(await store.getChannelUnreadCount('79426d8d', 3), 2);

        final c = _container(session: session, pubKeyPrefix: '79426d8d');
        addTearDown(c.dispose);

        // Force the notifier to build.
        c.read(meshCoreConversationsProvider);
        // Drain notifier microtasks (the build path schedules deferred
        // work but the markAsRead path doesn't depend on it completing).
        await Future<void>.delayed(Duration.zero);

        await c
            .read(meshCoreConversationsProvider.notifier)
            .markAsRead('channel_3');

        expect(await store.getChannelUnreadCount('79426d8d', 3), 0);
      },
    );

    test('malformed channel id does NOT throw', () async {
      final c = _container(session: session, pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      c.read(meshCoreConversationsProvider);
      await Future<void>.delayed(Duration.zero);

      // Should silently log + return.
      await c
          .read(meshCoreConversationsProvider.notifier)
          .markAsRead('channel_not_a_number');
      await c
          .read(meshCoreConversationsProvider.notifier)
          .markAsRead('channel_');
    });

    test(
      'empty device prefix is a no-op (no global key materialises)',
      () async {
        final c = _container(session: session, pubKeyPrefix: '');
        addTearDown(c.dispose);
        c.read(meshCoreConversationsProvider);
        await Future<void>.delayed(Duration.zero);

        await c
            .read(meshCoreConversationsProvider.notifier)
            .markAsRead('channel_3');
        final prefs = await SharedPreferences.getInstance();
        final ours = prefs.getKeys().where(
          (k) => k.startsWith('meshcore_channel_unread_'),
        );
        expect(ours, isEmpty);
      },
    );

    test('markAsRead on a contact id does NOT touch the channel-unread '
        'keyspace (orthogonality)', () async {
      // Pre-seed channel-unread disk.
      final store = MeshCoreContactStore();
      await store.incrementChannelUnreadCount('79426d8d', 3);
      expect(await store.getChannelUnreadCount('79426d8d', 3), 1);

      final c = _container(session: session, pubKeyPrefix: '79426d8d');
      addTearDown(c.dispose);
      c.read(meshCoreConversationsProvider);
      await Future<void>.delayed(Duration.zero);

      await c
          .read(meshCoreConversationsProvider.notifier)
          .markAsRead('contact_pubkey_hex_aaa');

      // Channel unread untouched.
      expect(await store.getChannelUnreadCount('79426d8d', 3), 1);
    });
  });
}
