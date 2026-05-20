// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Phase 4 Slice A - pins the IFTTT custom-URL webhook body shape
// for protocol-tagged events. The Meshtastic path stays back-compat
// with applets subscribed to `meshtastic_message` and unaware of
// `protocol`; the MeshCore path surfaces a new `meshcore_message`
// event name AND a `protocol: 'meshcore'` JSON field so downstream
// applets (Home Assistant, n8n, Node-RED) can branch on the source.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/trigger_protocol.dart';
import 'package:socialmesh/services/ifttt/ifttt_service.dart';

void main() {
  group('buildIftttCustomUrlBody', () {
    final fixedTs = DateTime.utc(2026, 5, 20, 10, 30, 0);

    test('includes protocol=meshcore when tagged meshcore', () {
      final body = buildIftttCustomUrlBody(
        eventName: 'meshcore_message',
        value1: 'TerryDev2',
        value2: 'Hello',
        value3: 'Direct Message',
        protocol: TriggerProtocol.meshcore,
        timestamp: fixedTs,
      );

      expect(body['event'], 'meshcore_message');
      expect(body['protocol'], 'meshcore');
      expect(body['value1'], 'TerryDev2');
      expect(body['value2'], 'Hello');
      expect(body['value3'], 'Direct Message');
      expect(body['timestamp'], fixedTs.toIso8601String());
    });

    test('includes protocol=meshtastic when tagged meshtastic', () {
      final body = buildIftttCustomUrlBody(
        eventName: 'meshtastic_message',
        value1: 'AlphaNode',
        value2: 'Hi',
        value3: 'Direct Message',
        protocol: TriggerProtocol.meshtastic,
        timestamp: fixedTs,
      );

      expect(body['event'], 'meshtastic_message');
      expect(body['protocol'], 'meshtastic');
    });

    test('omits protocol field entirely when tag is null (back-compat)', () {
      // Triggers not yet protocol-aware (battery / position / etc.)
      // pass null - we must NOT write `"protocol": null` into the
      // JSON body because some downstream handlers reject unknown
      // protocol values strictly. Omitting the key preserves the
      // pre-Slice-A body shape exactly.
      final body = buildIftttCustomUrlBody(
        eventName: 'meshtastic_battery_low',
        value1: 'AlphaNode',
        value2: '15%',
        timestamp: fixedTs,
      );

      expect(body.containsKey('protocol'), isFalse);
      expect(body['event'], 'meshtastic_battery_low');
    });

    test('omits null value1/2/3 fields (back-compat)', () {
      final body = buildIftttCustomUrlBody(
        eventName: 'meshcore_message',
        value1: 'OnlyValue1',
        protocol: TriggerProtocol.meshcore,
        timestamp: fixedTs,
      );

      expect(body.containsKey('value1'), isTrue);
      expect(body.containsKey('value2'), isFalse);
      expect(body.containsKey('value3'), isFalse);
    });

    test('timestamp is ISO-8601', () {
      final body = buildIftttCustomUrlBody(
        eventName: 'whatever',
        timestamp: fixedTs,
      );

      expect(body['timestamp'], '2026-05-20T10:30:00.000Z');
    });
  });
}
