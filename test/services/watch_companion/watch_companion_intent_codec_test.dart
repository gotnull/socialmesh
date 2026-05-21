// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_canned_messages.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_intent.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_intent_result.dart';

void main() {
  group('WatchCompanionIntent JSON round-trip', () {
    test('round-trips a quickMessage with cannedKey + channel target', () {
      final intent = WatchCompanionIntent(
        requestId: 'req-abc-123',
        type: WatchCompanionIntentType.quickMessage,
        target: const WatchCompanionIntentTarget(channelIndex: 0),
        payload: const WatchCompanionIntentPayload(
          cannedKey: WatchCompanionCannedMessageKeys.onMyWay,
        ),
        createdAtMs: 1747700000000,
      );

      final encoded = jsonEncode(intent.toJson());
      final decoded = WatchCompanionIntent.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(decoded, equals(intent));
    });

    test('round-trips every intent type via wire name', () {
      for (final type in WatchCompanionIntentType.values) {
        final intent = WatchCompanionIntent(
          requestId: 'req-${type.name}',
          type: type,
          target: const WatchCompanionIntentTarget(),
          payload: const WatchCompanionIntentPayload(),
          createdAtMs: 1,
        );
        final decoded = WatchCompanionIntent.fromJson(
          jsonDecode(jsonEncode(intent.toJson())) as Map<String, dynamic>,
        );
        expect(decoded.type, equals(type));
        expect(decoded, equals(intent));
      }
    });

    test('refreshSnapshot carries no payload or target', () {
      final intent = WatchCompanionIntent(
        requestId: 'refresh-1',
        type: WatchCompanionIntentType.refreshSnapshot,
        target: const WatchCompanionIntentTarget(),
        payload: const WatchCompanionIntentPayload(),
        createdAtMs: 42,
      );
      final json = intent.toJson();
      expect((json['target'] as Map)['channelIndex'], isNull);
      expect((json['payload'] as Map)['cannedKey'], isNull);
    });

    test('serialized version field is 1', () {
      final intent = WatchCompanionIntent(
        requestId: 'r',
        type: WatchCompanionIntentType.refreshSnapshot,
        target: const WatchCompanionIntentTarget(),
        payload: const WatchCompanionIntentPayload(),
        createdAtMs: 1,
      );
      expect(intent.toJson()['version'], equals(1));
    });

    test('rejects mismatched wire-version with FormatException', () {
      final intent = WatchCompanionIntent(
        requestId: 'r',
        type: WatchCompanionIntentType.refreshSnapshot,
        target: const WatchCompanionIntentTarget(),
        payload: const WatchCompanionIntentPayload(),
        createdAtMs: 1,
      );
      final json = intent.toJson()..['version'] = 2;
      expect(
        () => WatchCompanionIntent.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown intent type with FormatException', () {
      expect(
        () => WatchCompanionIntentType.fromWire('teleport'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('WatchCompanionIntentResult JSON round-trip', () {
    test('round-trips an accepted result', () {
      const result = WatchCompanionIntentResult(
        requestId: 'req-1',
        accepted: true,
        timestampMs: 1747700000000,
      );
      final decoded = WatchCompanionIntentResult.fromJson(
        jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, equals(result));
      expect(decoded.userVisibleReason, isNull);
      expect(decoded.diagnosticReason, isNull);
    });

    test('round-trips a rejected result with both reasons', () {
      const result = WatchCompanionIntentResult(
        requestId: 'req-2',
        accepted: false,
        userVisibleReason: 'Radio not ready',
        diagnosticReason: 'readiness_not_ready',
        timestampMs: 1747700001000,
      );
      final decoded = WatchCompanionIntentResult.fromJson(
        jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, equals(result));
    });

    test('serialized version field is 1', () {
      const result = WatchCompanionIntentResult(
        requestId: 'r',
        accepted: true,
        timestampMs: 1,
      );
      expect(result.toJson()['version'], equals(1));
    });

    test('rejects mismatched wire-version', () {
      const result = WatchCompanionIntentResult(
        requestId: 'r',
        accepted: true,
        timestampMs: 1,
      );
      final json = result.toJson()..['version'] = 0;
      expect(
        () => WatchCompanionIntentResult.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
