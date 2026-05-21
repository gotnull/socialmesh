// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/watch_companion/_internal/watch_channels_facade.dart';
import 'package:socialmesh/services/watch_companion/_internal/watch_inbox_facade.dart';
import 'package:socialmesh/services/watch_companion/_internal/watch_node_preview_composer.dart';
import 'package:socialmesh/services/watch_companion/_internal/watch_readiness_facade.dart';
import 'package:socialmesh/services/watch_companion/_internal/watch_snapshot_composer.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_canned_messages.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_channel_preview.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_connection_state.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_inbox_preview.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_node_preview.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_snapshot.dart';
import 'package:socialmesh/services/watch_companion/watch_companion_feature_flags.dart';
import 'package:socialmesh/services/watch_companion/watch_companion_providers.dart';
import 'package:socialmesh/services/watch_companion/watch_companion_service.dart';

WatchCompanionInboxMessage _msg(int i, {bool unread = false}) {
  return WatchCompanionInboxMessage(
    id: 'm-$i',
    sender: 'peer-$i',
    snippet: 'message $i',
    timestampMs: 1747700000000 + i,
    unread: unread,
    channelIndex: 0,
  );
}

WatchCompanionNodePreview _node(int i) {
  return WatchCompanionNodePreview(
    nodeId: '$i',
    shortName: 'n$i',
    longName: 'node $i',
    lastHeardMs: 1747700000000 + i,
  );
}

WatchCompanionChannelPreview _ch(int i, {bool isDefault = false}) {
  return WatchCompanionChannelPreview(
    index: i,
    name: 'ch $i',
    isDefault: isDefault,
  );
}

ProviderContainer _containerWith({
  WatchCompanionConnectionState? readiness,
  WatchCompanionInboxPreview? inbox,
  List<WatchCompanionNodePreview>? nodes,
  List<WatchCompanionChannelPreview>? channels,
  bool readinessThrows = false,
  bool inboxThrows = false,
  bool nodesThrows = false,
  bool channelsThrows = false,
}) {
  return ProviderContainer(
    overrides: [
      if (readinessThrows)
        watchReadinessFacadeProvider.overrideWith(
          (ref) => throw StateError('readiness boom'),
        )
      else
        watchReadinessFacadeProvider.overrideWith(
          (ref) =>
              readiness ??
              const WatchCompanionConnectionState(
                status: WatchCompanionConnectionStatus.ready,
                activeProtocolDisplayName: 'Meshtastic',
                activeDeviceName: 'Heltec V3',
              ),
        ),
      if (inboxThrows)
        watchInboxFacadeProvider.overrideWith(
          (ref) => throw StateError('inbox boom'),
        )
      else
        watchInboxFacadeProvider.overrideWith(
          (ref) =>
              inbox ??
              const WatchCompanionInboxPreview(
                unreadCount: 0,
                previews: <WatchCompanionInboxMessage>[],
              ),
        ),
      if (nodesThrows)
        watchNodePreviewProvider.overrideWith(
          (ref) => throw StateError('nodes boom'),
        )
      else
        watchNodePreviewProvider.overrideWith(
          (ref) => nodes ?? const <WatchCompanionNodePreview>[],
        ),
      if (channelsThrows)
        watchChannelsFacadeProvider.overrideWith(
          (ref) => throw StateError('channels boom'),
        )
      else
        watchChannelsFacadeProvider.overrideWith(
          (ref) => channels ?? const <WatchCompanionChannelPreview>[],
        ),
    ],
  );
}

void main() {
  group('watchSnapshotComposerProvider', () {
    test(
      'emits a fully-populated snapshot with v1 frozen canned-message order',
      () {
        final container = _containerWith(
          inbox: WatchCompanionInboxPreview(
            unreadCount: 2,
            previews: <WatchCompanionInboxMessage>[
              _msg(1, unread: true),
              _msg(2),
            ],
          ),
          nodes: <WatchCompanionNodePreview>[_node(1), _node(2)],
          channels: <WatchCompanionChannelPreview>[
            _ch(0, isDefault: true),
            _ch(1),
          ],
        );
        addTearDown(container.dispose);

        final snap = container.read(watchSnapshotComposerProvider);

        expect(snap.generatedAt, greaterThan(0));
        expect(snap.connection.status, WatchCompanionConnectionStatus.ready);
        expect(snap.inbox.unreadCount, 2);
        expect(snap.inbox.previews, hasLength(2));
        expect(snap.nodes, hasLength(2));
        expect(snap.channels, hasLength(2));
        expect(
          snap.cannedMessages.map((m) => m.key).toList(),
          WatchCompanionCannedMessageKeys.all,
          reason: 'Canned-message key order is frozen for v1.',
        );
        expect(snap.capabilities.canQuickReply, isTrue);
        expect(snap.capabilities.canSendImOk, isTrue);
        expect(snap.capabilities.canSendLocationIntent, isFalse);
        expect(snap.capabilities.canShowInbox, isTrue);
        expect(snap.capabilities.canShowNodes, isTrue);
      },
    );

    test('inbox preview is trimmed to 5 by the composer even when a facade '
        'leaks more', () {
      final tenMessages = List<WatchCompanionInboxMessage>.generate(
        10,
        (i) => _msg(i),
      );
      final container = _containerWith(
        inbox: WatchCompanionInboxPreview(
          unreadCount: 10,
          previews: tenMessages,
        ),
      );
      addTearDown(container.dispose);

      final snap = container.read(watchSnapshotComposerProvider);

      expect(snap.inbox.previews, hasLength(5));
      expect(
        snap.inbox.unreadCount,
        10,
        reason: 'Capping the visible rows must NOT mangle the unread badge.',
      );
      // First 5 of the input list are surfaced; order preserved.
      expect(snap.inbox.previews.map((m) => m.id).toList(), [
        'm-0',
        'm-1',
        'm-2',
        'm-3',
        'm-4',
      ]);
    });

    test('node preview is trimmed to 5 by the composer even when a facade '
        'leaks more', () {
      final tenNodes = List<WatchCompanionNodePreview>.generate(
        10,
        (i) => _node(i),
      );
      final container = _containerWith(nodes: tenNodes);
      addTearDown(container.dispose);

      final snap = container.read(watchSnapshotComposerProvider);

      expect(snap.nodes, hasLength(5));
      expect(snap.nodes.map((n) => n.nodeId).toList(), [
        '0',
        '1',
        '2',
        '3',
        '4',
      ]);
    });

    test('default channel index marks exactly one channel when it matches', () {
      final container = _containerWith(
        channels: <WatchCompanionChannelPreview>[
          _ch(0, isDefault: false),
          _ch(1, isDefault: true),
          _ch(2, isDefault: false),
        ],
      );
      addTearDown(container.dispose);

      final snap = container.read(watchSnapshotComposerProvider);
      final defaults = snap.channels.where((c) => c.isDefault).toList();

      expect(defaults, hasLength(1));
      expect(defaults.single.index, 1);
    });

    test('no channel is marked default when no channel matches the index', () {
      // Facade returned channels with isDefault=false for all (caller picked
      // a default index that does not exist). Composer must NOT auto-promote
      // one to default.
      final container = _containerWith(
        channels: <WatchCompanionChannelPreview>[
          _ch(0, isDefault: false),
          _ch(1, isDefault: false),
        ],
      );
      addTearDown(container.dispose);

      final snap = container.read(watchSnapshotComposerProvider);
      expect(snap.channels.where((c) => c.isDefault), isEmpty);
    });

    test(
      'readiness slice failure degrades to unsupported without throwing',
      () {
        final container = _containerWith(readinessThrows: true);
        addTearDown(container.dispose);

        final snap = container.read(watchSnapshotComposerProvider);
        expect(
          snap.connection.status,
          WatchCompanionConnectionStatus.unsupported,
        );
        expect(snap.connection.readinessReason, 'readiness_facade_unavailable');
        // Other slices still rendered.
        expect(snap.cannedMessages, isNotEmpty);
      },
    );

    test('inbox slice failure degrades to empty preview', () {
      final container = _containerWith(inboxThrows: true);
      addTearDown(container.dispose);

      final snap = container.read(watchSnapshotComposerProvider);
      expect(snap.inbox.previews, isEmpty);
      expect(snap.inbox.unreadCount, 0);
      expect(snap.capabilities.canShowInbox, isFalse);
    });

    test('nodes slice failure degrades to empty node list', () {
      final container = _containerWith(nodesThrows: true);
      addTearDown(container.dispose);

      final snap = container.read(watchSnapshotComposerProvider);
      expect(snap.nodes, isEmpty);
      expect(snap.capabilities.canShowNodes, isFalse);
    });

    test('channels slice failure degrades to empty channel list', () {
      final container = _containerWith(channelsThrows: true);
      addTearDown(container.dispose);

      final snap = container.read(watchSnapshotComposerProvider);
      expect(snap.channels, isEmpty);
    });

    test(
      'all slice failures simultaneously still produce a valid snapshot',
      () {
        final container = _containerWith(
          readinessThrows: true,
          inboxThrows: true,
          nodesThrows: true,
          channelsThrows: true,
        );
        addTearDown(container.dispose);

        final snap = container.read(watchSnapshotComposerProvider);

        expect(snap.generatedAt, greaterThan(0));
        expect(
          snap.connection.status,
          WatchCompanionConnectionStatus.unsupported,
        );
        expect(snap.inbox.previews, isEmpty);
        expect(snap.nodes, isEmpty);
        expect(snap.channels, isEmpty);
        expect(snap.cannedMessages, isNotEmpty);
        // No flag fires; the snapshot still round-trips through JSON.
        expect(WatchCompanionSnapshot.fromJson(snap.toJson()), equals(snap));
      },
    );
  });

  group('watchCompanionServiceProvider', () {
    test('returns NoOp service when feature flag is disabled', () async {
      final container = ProviderContainer(
        overrides: [
          watchCompanionFeatureFlagsProvider.overrideWith(
            (ref) => WatchCompanionFeatureFlags.disabled,
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(watchCompanionServiceProvider);
      expect(service, isA<NoOpWatchCompanionService>());

      // NoOp service emits a single "unsupported" snapshot.
      final snap = await service.snapshots.first;
      expect(
        snap.connection.status,
        WatchCompanionConnectionStatus.unsupported,
      );
      expect(snap.capabilities.canQuickReply, isFalse);
      expect(snap.capabilities.canSendImOk, isFalse);
      expect(snap.cannedMessages, isEmpty);
    });

    test(
      'returns ComposingWatchCompanionService when feature flag is enabled',
      () {
        final container = ProviderContainer(
          overrides: [
            watchCompanionFeatureFlagsProvider.overrideWith(
              (ref) => const WatchCompanionFeatureFlags(enabled: true),
            ),
            // Stub the facades so the composing service can build a real
            // snapshot without standing up the full Meshtastic/MeshCore
            // provider tree.
            watchReadinessFacadeProvider.overrideWith(
              (ref) => const WatchCompanionConnectionState(
                status: WatchCompanionConnectionStatus.disconnected,
              ),
            ),
            watchInboxFacadeProvider.overrideWith(
              (ref) => const WatchCompanionInboxPreview(
                unreadCount: 0,
                previews: <WatchCompanionInboxMessage>[],
              ),
            ),
            watchNodePreviewProvider.overrideWith(
              (ref) => const <WatchCompanionNodePreview>[],
            ),
            watchChannelsFacadeProvider.overrideWith(
              (ref) => const <WatchCompanionChannelPreview>[],
            ),
          ],
        );
        addTearDown(container.dispose);

        final service = container.read(watchCompanionServiceProvider);
        expect(service, isNot(isA<NoOpWatchCompanionService>()));

        // Service should have seeded the latest snapshot synchronously in
        // its constructor so the iOS bridge can read it on session activate
        // without waiting for the next stream tick.
        expect(service.latestSnapshot, isNotNull);
        expect(
          service.latestSnapshot!.connection.status,
          WatchCompanionConnectionStatus.disconnected,
        );
      },
    );

    test('disabled-then-enabled flip swaps the service implementation', () {
      var enabled = false;
      final container = ProviderContainer(
        overrides: [
          watchCompanionFeatureFlagsProvider.overrideWith(
            (ref) => WatchCompanionFeatureFlags(enabled: enabled),
          ),
          watchReadinessFacadeProvider.overrideWith(
            (ref) => const WatchCompanionConnectionState(
              status: WatchCompanionConnectionStatus.disconnected,
            ),
          ),
          watchInboxFacadeProvider.overrideWith(
            (ref) => const WatchCompanionInboxPreview(
              unreadCount: 0,
              previews: <WatchCompanionInboxMessage>[],
            ),
          ),
          watchNodePreviewProvider.overrideWith(
            (ref) => const <WatchCompanionNodePreview>[],
          ),
          watchChannelsFacadeProvider.overrideWith(
            (ref) => const <WatchCompanionChannelPreview>[],
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(watchCompanionServiceProvider),
        isA<NoOpWatchCompanionService>(),
      );

      enabled = true;
      container.invalidate(watchCompanionFeatureFlagsProvider);

      expect(
        container.read(watchCompanionServiceProvider),
        isNot(isA<NoOpWatchCompanionService>()),
      );
    });
  });
}
