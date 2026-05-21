// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/watch_companion/_internal/watch_capabilities_composer.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_connection_state.dart';

void main() {
  group('deriveWatchCapabilities', () {
    WatchCompanionConnectionState connectionWith(
      WatchCompanionConnectionStatus status,
    ) {
      return WatchCompanionConnectionState(status: status);
    }

    test('canQuickReply + canSendImOk are true only when status == ready', () {
      for (final status in WatchCompanionConnectionStatus.values) {
        final caps = deriveWatchCapabilities(
          connection: connectionWith(status),
          inboxHasData: false,
          nodesHasData: false,
        );
        final expectSend = status == WatchCompanionConnectionStatus.ready;
        expect(
          caps.canQuickReply,
          equals(expectSend),
          reason: 'status=$status should yield canQuickReply=$expectSend',
        );
        expect(
          caps.canSendImOk,
          equals(expectSend),
          reason: 'status=$status should yield canSendImOk=$expectSend',
        );
      }
    });

    test('canSendLocationIntent is always false in v1', () {
      for (final status in WatchCompanionConnectionStatus.values) {
        for (final inbox in [true, false]) {
          for (final nodes in [true, false]) {
            final caps = deriveWatchCapabilities(
              connection: connectionWith(status),
              inboxHasData: inbox,
              nodesHasData: nodes,
            );
            expect(
              caps.canSendLocationIntent,
              isFalse,
              reason:
                  'Location intent is reserved for v2; never true in v1 '
                  '(status=$status, inbox=$inbox, nodes=$nodes).',
            );
          }
        }
      }
    });

    test('canShowInbox tracks inboxHasData flag', () {
      final hasInbox = deriveWatchCapabilities(
        connection: connectionWith(WatchCompanionConnectionStatus.ready),
        inboxHasData: true,
        nodesHasData: false,
      );
      expect(hasInbox.canShowInbox, isTrue);

      final noInbox = deriveWatchCapabilities(
        connection: connectionWith(WatchCompanionConnectionStatus.ready),
        inboxHasData: false,
        nodesHasData: false,
      );
      expect(noInbox.canShowInbox, isFalse);
    });

    test('canShowNodes tracks nodesHasData flag', () {
      final hasNodes = deriveWatchCapabilities(
        connection: connectionWith(WatchCompanionConnectionStatus.ready),
        inboxHasData: false,
        nodesHasData: true,
      );
      expect(hasNodes.canShowNodes, isTrue);

      final noNodes = deriveWatchCapabilities(
        connection: connectionWith(WatchCompanionConnectionStatus.ready),
        inboxHasData: false,
        nodesHasData: false,
      );
      expect(noNodes.canShowNodes, isFalse);
    });

    test(
      'showing inbox/nodes does not require ready (decoupled from send)',
      () {
        // A disconnected Watch should still show recent inbox + nodes from
        // the local cache; only sending is gated on readiness.
        final caps = deriveWatchCapabilities(
          connection: connectionWith(
            WatchCompanionConnectionStatus.disconnected,
          ),
          inboxHasData: true,
          nodesHasData: true,
        );
        expect(caps.canShowInbox, isTrue);
        expect(caps.canShowNodes, isTrue);
        expect(caps.canQuickReply, isFalse);
        expect(caps.canSendImOk, isFalse);
      },
    );
  });
}
