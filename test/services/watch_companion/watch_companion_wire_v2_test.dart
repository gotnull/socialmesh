// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the v2 wire contract for the watch companion:
//   - intents/results accept the [minWireVersion, wireVersion] range
//   - v1 payloads (missing the new optional fields) still decode
//   - the new reply fields round-trip
//   - out-of-range versions are rejected loudly

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_inbox_preview.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_intent.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_intent_result.dart';

void main() {
  group('WatchCompanionIntent v2 wire', () {
    test('is wire-version 2', () {
      expect(WatchCompanionIntent.wireVersion, 2);
      expect(WatchCompanionIntent.minWireVersion, 1);
    });

    test('round-trips replyToMessageId', () {
      final intent = WatchCompanionIntent(
        requestId: 'r1',
        type: WatchCompanionIntentType.quickMessage,
        target: const WatchCompanionIntentTarget(channelIndex: 2),
        payload: const WatchCompanionIntentPayload(
          cannedKey: 'on_my_way',
          replyToMessageId: 'pkt-aa-bb',
        ),
        createdAtMs: 1,
      );
      final decoded = WatchCompanionIntent.fromJson(intent.toJson());
      expect(decoded.payload.replyToMessageId, 'pkt-aa-bb');
      expect(decoded.payload.cannedKey, 'on_my_way');
    });

    test('decodes a v1 intent (no replyToMessageId) with null reply', () {
      final v1 = <String, dynamic>{
        'version': 1,
        'requestId': 'r1',
        'type': 'quickMessage',
        'target': {'channelIndex': 0},
        'payload': {'cannedKey': 'im_ok'},
        'createdAtMs': 1,
      };
      final decoded = WatchCompanionIntent.fromJson(v1);
      expect(decoded.payload.replyToMessageId, isNull);
      expect(decoded.payload.cannedKey, 'im_ok');
    });

    test('rejects out-of-range versions', () {
      Map<String, dynamic> withVersion(Object? v) => <String, dynamic>{
        'version': v,
        'requestId': 'r1',
        'type': 'quickMessage',
        'target': {'channelIndex': 0},
        'payload': {'cannedKey': 'im_ok'},
        'createdAtMs': 1,
      };
      expect(
        () => WatchCompanionIntent.fromJson(withVersion(0)),
        throwsFormatException,
      );
      expect(
        () => WatchCompanionIntent.fromJson(withVersion(99)),
        throwsFormatException,
      );
      expect(
        () => WatchCompanionIntent.fromJson(withVersion(null)),
        throwsFormatException,
      );
    });
  });

  group('WatchCompanionInboxMessage v2 wire', () {
    test('round-trips packetId', () {
      const msg = WatchCompanionInboxMessage(
        id: 'pkt-aa-bb',
        sender: 'Node',
        snippet: 'hi',
        timestampMs: 1,
        unread: true,
        channelIndex: 0,
        packetId: 0xBB,
      );
      final decoded = WatchCompanionInboxMessage.fromJson(msg.toJson());
      expect(decoded.packetId, 0xBB);
    });

    test('decodes a v1 row (no packetId) with null packetId', () {
      final v1 = <String, dynamic>{
        'id': 'm1',
        'sender': 'Node',
        'snippet': 'hi',
        'timestampMs': 1,
        'unread': false,
        'channelIndex': 0,
      };
      final decoded = WatchCompanionInboxMessage.fromJson(v1);
      expect(decoded.packetId, isNull);
    });
  });

  group('WatchCompanionIntentResult v2 wire', () {
    test('accepts the version range, rejects out-of-range', () {
      Map<String, dynamic> withVersion(Object? v) => <String, dynamic>{
        'version': v,
        'requestId': 'r1',
        'accepted': true,
        'userVisibleReason': null,
        'diagnosticReason': null,
        'timestampMs': 1,
      };
      // v1 and v2 both decode.
      expect(
        WatchCompanionIntentResult.fromJson(withVersion(1)).accepted,
        isTrue,
      );
      expect(
        WatchCompanionIntentResult.fromJson(withVersion(2)).accepted,
        isTrue,
      );
      expect(
        () => WatchCompanionIntentResult.fromJson(withVersion(3)),
        throwsFormatException,
      );
    });
  });
}
