// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D38-A - `_loadConversations` rebuilds channel conversation entries
// from `meshCoreChannelsProvider` + the on-disk MeshCoreMessageStore +
// the per-channel unread persistence.
//
// Pinned invariants:
//   - After refresh(), state.conversations contains an entry per
//     channel slot known to `meshCoreChannelsProvider`.
//   - Channel unread badge survives a refresh: the persisted count is
//     surfaced as `MeshCoreConversation.unreadCount`.
//   - Channel preview survives a refresh: the LAST persisted channel
//     message's text is surfaced as `MeshCoreConversation
//     .lastMessageText`.
//   - Channels with no persisted messages render with null preview
//     (no fabrication).
//   - The contact rebuild path is unchanged (no contacts seeded means
//     no contact conversations).
//   - Channel IDs use the `channel_<idx>` shape (matches the rest of
//     the codebase).

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/models/meshcore_channel.dart';
import 'package:socialmesh/providers/meshcore_message_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_contact_store.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_message_store.dart';

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

class _StubChannelsNotifier extends MeshCoreChannelsNotifier {
  _StubChannelsNotifier(this._seed);
  final List<MeshCoreChannel> _seed;
  @override
  MeshCoreChannelsState build() =>
      MeshCoreChannelsState(channels: List.unmodifiable(_seed));
  @override
  Future<void> refresh() async {}
}

MeshCoreChannel _channel(int index, String name) => MeshCoreChannel(
  index: index,
  name: name,
  psk: Uint8List.fromList(List.generate(16, (i) => i + index + 1)),
);

ProviderContainer _container({
  required List<MeshCoreChannel> channels,
  required String pubKeyPrefix,
  required MeshCoreSession session,
}) {
  return ProviderContainer(
    overrides: [
      meshCoreSessionProvider.overrideWithValue(session),
      meshCoreChannelsProvider.overrideWith(
        () => _StubChannelsNotifier(channels),
      ),
      meshCoreSelfPubKeyPrefixProvider.overrideWith((ref) => pubKeyPrefix),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeTransport transport;
  late MeshCoreSession session;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    transport = _FakeTransport();
    session = MeshCoreSession(transport);
  });

  tearDown(() async {
    await transport.dispose();
  });

  test(
    'refresh() rebuilds a channel conversation per known channel slot',
    () async {
      final c = _container(
        channels: [_channel(0, 'Alpha'), _channel(1, 'Beta')],
        pubKeyPrefix: '79426d8d',
        session: session,
      );
      addTearDown(c.dispose);

      c.read(meshCoreConversationsProvider);
      await c.read(meshCoreConversationsProvider.notifier).refresh();

      final state = c.read(meshCoreConversationsProvider);
      final ids = state.conversations.map((cn) => cn.id).toSet();
      expect(ids, containsAll(<String>['channel_0', 'channel_1']));
    },
  );

  test('persisted channel unread survives a refresh', () async {
    final store = MeshCoreContactStore();
    await store.incrementChannelUnreadCount('79426d8d', 1);
    await store.incrementChannelUnreadCount('79426d8d', 1);
    await store.incrementChannelUnreadCount('79426d8d', 1);

    final c = _container(
      channels: [_channel(0, 'Alpha'), _channel(1, 'Beta')],
      pubKeyPrefix: '79426d8d',
      session: session,
    );
    addTearDown(c.dispose);
    c.read(meshCoreConversationsProvider);
    await c.read(meshCoreConversationsProvider.notifier).refresh();

    final beta = c
        .read(meshCoreConversationsProvider)
        .conversations
        .firstWhere((cn) => cn.id == 'channel_1');
    expect(beta.unreadCount, 3);
    expect(beta.isChannel, isTrue);
    expect(beta.channelIndex, 1);
    expect(beta.name, 'Beta');
  });

  test('persisted last channel message surfaces as preview', () async {
    final msgStore = MeshCoreMessageStore();
    await msgStore.init();
    // Two persisted messages on slot 1; the last one wins for preview.
    await msgStore.saveChannelMessages(1, [
      MeshCoreStoredMessage(
        id: 'm1',
        senderKey: Uint8List(0),
        text: 'first',
        timestamp: DateTime(2026, 5, 11, 12),
        isOutgoing: false,
        isChannelMessage: true,
        channelIndex: 1,
      ),
      MeshCoreStoredMessage(
        id: 'm2',
        senderKey: Uint8List(0),
        text: 'second (preview wins)',
        timestamp: DateTime(2026, 5, 11, 12, 5),
        isOutgoing: false,
        isChannelMessage: true,
        channelIndex: 1,
      ),
    ]);

    final c = _container(
      channels: [_channel(1, 'Beta')],
      pubKeyPrefix: '79426d8d',
      session: session,
    );
    addTearDown(c.dispose);
    c.read(meshCoreConversationsProvider);
    await c.read(meshCoreConversationsProvider.notifier).refresh();

    final beta = c
        .read(meshCoreConversationsProvider)
        .conversations
        .firstWhere((cn) => cn.id == 'channel_1');
    expect(beta.lastMessageText, 'second (preview wins)');
    expect(beta.lastMessageTime, DateTime(2026, 5, 11, 12, 5));
  });

  test('channel with no persisted messages has null preview', () async {
    final c = _container(
      channels: [_channel(2, 'Gamma')],
      pubKeyPrefix: '79426d8d',
      session: session,
    );
    addTearDown(c.dispose);
    c.read(meshCoreConversationsProvider);
    await c.read(meshCoreConversationsProvider.notifier).refresh();

    final gamma = c
        .read(meshCoreConversationsProvider)
        .conversations
        .firstWhere((cn) => cn.id == 'channel_2');
    expect(gamma.lastMessageText, isNull);
    expect(gamma.lastMessageTime, isNull);
    expect(gamma.unreadCount, 0);
  });

  test('refresh() does NOT fabricate contact conversations when no '
      'contacts are seeded', () async {
    // No contacts in the store. Channels still rebuild but no contact
    // conversations show up.
    final c = _container(
      channels: [_channel(0, 'Alpha')],
      pubKeyPrefix: '79426d8d',
      session: session,
    );
    addTearDown(c.dispose);
    c.read(meshCoreConversationsProvider);
    await c.read(meshCoreConversationsProvider.notifier).refresh();

    final state = c.read(meshCoreConversationsProvider);
    final contactConvs = state.conversations.where((cn) => !cn.isChannel);
    expect(
      contactConvs,
      isEmpty,
      reason: 'no contacts seeded -> no contact conversations',
    );
  });

  test('markAsRead followed by refresh keeps the unread at 0 (persistence '
      'survives the full cycle)', () async {
    final store = MeshCoreContactStore();
    await store.incrementChannelUnreadCount('79426d8d', 1);
    await store.incrementChannelUnreadCount('79426d8d', 1);

    final c = _container(
      channels: [_channel(1, 'Beta')],
      pubKeyPrefix: '79426d8d',
      session: session,
    );
    addTearDown(c.dispose);
    c.read(meshCoreConversationsProvider);
    await c.read(meshCoreConversationsProvider.notifier).refresh();
    var beta = c
        .read(meshCoreConversationsProvider)
        .conversations
        .firstWhere((cn) => cn.id == 'channel_1');
    expect(beta.unreadCount, 2);

    await c
        .read(meshCoreConversationsProvider.notifier)
        .markAsRead('channel_1');

    // The on-disk count is cleared; rebuild must surface 0.
    await c.read(meshCoreConversationsProvider.notifier).refresh();
    beta = c
        .read(meshCoreConversationsProvider)
        .conversations
        .firstWhere((cn) => cn.id == 'channel_1');
    expect(beta.unreadCount, 0);
  });

  test('empty device prefix: no channel conversations are written even '
      'when channels are present (unread comes back as 0)', () async {
    // Pre-seed a count under SOME device, but the notifier's prefix is
    // empty -> getChannelUnreadCount('', idx) returns 0.
    final store = MeshCoreContactStore();
    await store.incrementChannelUnreadCount('79426d8d', 1);

    final c = _container(
      channels: [_channel(1, 'Beta')],
      pubKeyPrefix: '',
      session: session,
    );
    addTearDown(c.dispose);
    c.read(meshCoreConversationsProvider);
    await c.read(meshCoreConversationsProvider.notifier).refresh();

    final beta = c
        .read(meshCoreConversationsProvider)
        .conversations
        .firstWhere((cn) => cn.id == 'channel_1');
    expect(
      beta.unreadCount,
      0,
      reason: 'no-pubkey path must NOT read another device prefix\'s count',
    );
  });
}
