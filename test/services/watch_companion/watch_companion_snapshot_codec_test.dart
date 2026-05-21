// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_canned_messages.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_capabilities.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_channel_preview.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_connection_state.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_inbox_preview.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_node_preview.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_snapshot.dart';

WatchCompanionSnapshot _buildSnapshot({
  WatchCompanionConnectionStatus status = WatchCompanionConnectionStatus.ready,
}) {
  return WatchCompanionSnapshot(
    generatedAt: 1747700000000,
    connection: WatchCompanionConnectionState(
      status: status,
      activeProtocolDisplayName: 'Meshtastic',
      activeDeviceName: 'Heltec V3',
      readinessReason: status == WatchCompanionConnectionStatus.ready
          ? null
          : 'Awaiting NodeDB',
    ),
    inbox: const WatchCompanionInboxPreview(
      unreadCount: 3,
      previews: <WatchCompanionInboxMessage>[
        WatchCompanionInboxMessage(
          id: 'm-1',
          sender: 'Alpha',
          snippet: 'Heading to the ridge',
          timestampMs: 1747699999000,
          unread: true,
          channelIndex: 0,
        ),
        WatchCompanionInboxMessage(
          id: 'm-2',
          sender: 'Bravo',
          snippet: 'See you at camp',
          timestampMs: 1747699998000,
          unread: false,
        ),
      ],
    ),
    nodes: const <WatchCompanionNodePreview>[
      WatchCompanionNodePreview(
        nodeId: '123456',
        shortName: 'A1',
        longName: 'Alpha One',
        lastHeardMs: 1747699997000,
        rssi: -95,
        hops: 1,
      ),
      WatchCompanionNodePreview(nodeId: '789012', lastHeardMs: 1747699996000),
    ],
    channels: const <WatchCompanionChannelPreview>[
      WatchCompanionChannelPreview(index: 0, name: 'Primary', isDefault: true),
      WatchCompanionChannelPreview(index: 1, name: 'admin', isDefault: false),
    ],
    cannedMessages: const <WatchCompanionCannedMessage>[
      WatchCompanionCannedMessage(
        key: WatchCompanionCannedMessageKeys.onMyWay,
        label: 'On my way',
      ),
      WatchCompanionCannedMessage(
        key: WatchCompanionCannedMessageKeys.imOk,
        label: "I'm OK",
      ),
    ],
    capabilities: const WatchCompanionCapabilities(
      canQuickReply: true,
      canSendImOk: true,
      canSendLocationIntent: false,
      canShowNodes: true,
      canShowInbox: true,
    ),
  );
}

void main() {
  group('WatchCompanionSnapshot JSON round-trip', () {
    test('round-trips a fully populated snapshot byte-identically', () {
      final original = _buildSnapshot();

      final encoded = jsonEncode(original.toJson());
      final decoded = WatchCompanionSnapshot.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(decoded, equals(original));
      expect(jsonEncode(decoded.toJson()), equals(encoded));
    });

    test('round-trips every connection-status value', () {
      for (final status in WatchCompanionConnectionStatus.values) {
        final snap = _buildSnapshot(status: status);
        final decoded = WatchCompanionSnapshot.fromJson(
          jsonDecode(jsonEncode(snap.toJson())) as Map<String, dynamic>,
        );
        expect(decoded.connection.status, equals(status));
        expect(decoded, equals(snap));
      }
    });

    test('serialized version field is 1', () {
      final json = _buildSnapshot().toJson();
      expect(json['version'], equals(1));
    });

    test('rejects mismatched wire-version with FormatException', () {
      final json = _buildSnapshot().toJson()..['version'] = 999;
      expect(
        () => WatchCompanionSnapshot.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('handles empty inbox / nodes / channels gracefully', () {
      const empty = WatchCompanionSnapshot(
        generatedAt: 1,
        connection: WatchCompanionConnectionState(
          status: WatchCompanionConnectionStatus.disconnected,
        ),
        inbox: WatchCompanionInboxPreview(
          unreadCount: 0,
          previews: <WatchCompanionInboxMessage>[],
        ),
        nodes: <WatchCompanionNodePreview>[],
        channels: <WatchCompanionChannelPreview>[],
        cannedMessages: <WatchCompanionCannedMessage>[],
        capabilities: WatchCompanionCapabilities.none,
      );

      final encoded = jsonEncode(empty.toJson());
      final decoded = WatchCompanionSnapshot.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(decoded, equals(empty));
      expect(decoded.inbox.previews, isEmpty);
      expect(decoded.nodes, isEmpty);
      expect(decoded.channels, isEmpty);
      expect(decoded.cannedMessages, isEmpty);
    });
  });

  group('WatchCompanionConnectionStatus.fromWire', () {
    test('round-trips every value via name', () {
      for (final value in WatchCompanionConnectionStatus.values) {
        expect(
          WatchCompanionConnectionStatus.fromWire(value.toWire()),
          equals(value),
        );
      }
    });

    test('rejects unknown wire token', () {
      expect(
        () => WatchCompanionConnectionStatus.fromWire('mystery'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('WatchCompanionCannedMessageKeys', () {
    test('exposes the 6 frozen keys in plan order', () {
      expect(WatchCompanionCannedMessageKeys.all, <String>[
        'on_my_way',
        'im_ok',
        'need_help',
        'at_camp',
        'battery_low',
        'message_received',
      ]);
    });

    test('isKnown accepts each frozen key and rejects others', () {
      for (final key in WatchCompanionCannedMessageKeys.all) {
        expect(WatchCompanionCannedMessageKeys.isKnown(key), isTrue);
      }
      expect(WatchCompanionCannedMessageKeys.isKnown('nope'), isFalse);
      expect(WatchCompanionCannedMessageKeys.isKnown(''), isFalse);
    });
  });
}
