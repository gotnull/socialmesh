// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Issue #200 - notification taps must open the conversation. The payload
// parser is the routing decision for every local notification tap (warm
// stream and cold-start launch details), so its normalisation of the two
// payload conventions (`type|deepLink` and `type:targetId[:more]`) is
// pinned here.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/notifications/notification_payload_parser.dart';

void main() {
  group('parseLocalNotificationPayload', () {
    test('DM payload splits type and node number', () {
      final nav = parseLocalNotificationPayload('dm:305419896');
      expect(nav.type, 'dm');
      expect(nav.targetId, '305419896');
      expect(nav.deepLink, isNull);
    });

    test('channel payload keeps index and sender joined as targetId', () {
      final nav = parseLocalNotificationPayload('channel:2:999');
      expect(nav.type, 'channel');
      expect(nav.targetId, '2:999');
      expect(nav.deepLink, isNull);
    });

    test('MeshCore DM payload carries the public key hex', () {
      final nav = parseLocalNotificationPayload('meshcore-dm:a1b2c3d4e5f6');
      expect(nav.type, 'meshcore-dm');
      expect(nav.targetId, 'a1b2c3d4e5f6');
      expect(nav.deepLink, isNull);
    });

    test('MeshCore channel payload keeps index and sender prefix', () {
      final nav = parseLocalNotificationPayload('meshcore-channel:3:beef');
      expect(nav.type, 'meshcore-channel');
      expect(nav.targetId, '3:beef');
      expect(nav.deepLink, isNull);
    });

    test('pipe format wins over colons and deep link keeps its colons', () {
      final nav = parseLocalNotificationPayload(
        'announcement|https://example.com/a:b',
      );
      expect(nav.type, 'announcement');
      expect(nav.deepLink, 'https://example.com/a:b');
      expect(nav.targetId, isNull);
    });

    test('pipe format rejoins extra pipes into the deep link', () {
      final nav = parseLocalNotificationPayload('announcement|/route|extra');
      expect(nav.type, 'announcement');
      expect(nav.deepLink, '/route|extra');
      expect(nav.targetId, isNull);
    });

    test('bare payload is a type-only event', () {
      final nav = parseLocalNotificationPayload('sip_handshake_request');
      expect(nav.type, 'sip_handshake_request');
      expect(nav.targetId, isNull);
      expect(nav.deepLink, isNull);
    });

    test('trailing separator yields empty targetId, not a crash', () {
      final nav = parseLocalNotificationPayload('dm:');
      expect(nav.type, 'dm');
      expect(nav.targetId, '');
      expect(nav.deepLink, isNull);
    });
  });
}
