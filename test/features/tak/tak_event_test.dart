// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/tak/models/tak_event.dart';

void main() {
  group('TakEvent', () {
    final sampleJson = <String, dynamic>{
      'uid': 'ALPHA-01',
      'type': 'a-f-G-U-C',
      'callsign': 'ALPHA',
      'lat': 34.0522,
      'lon': -118.2437,
      'timeUtcMs': 1700000000000,
      'staleUtcMs': 1700000300000,
      'receivedUtcMs': 1700000001000,
      'rawXml': '{"detail":{}}',
    };

    test('fromJson parses all fields', () {
      final event = TakEvent.fromJson(sampleJson);

      expect(event.uid, 'ALPHA-01');
      expect(event.type, 'a-f-G-U-C');
      expect(event.callsign, 'ALPHA');
      expect(event.lat, 34.0522);
      expect(event.lon, -118.2437);
      expect(event.timeUtcMs, 1700000000000);
      expect(event.staleUtcMs, 1700000300000);
      expect(event.receivedUtcMs, 1700000001000);
      expect(event.rawPayloadJson, '{"detail":{}}');
    });

    test('fromJson with null optional fields', () {
      final minimal = <String, dynamic>{
        'uid': 'BRAVO-02',
        'type': 'a-h-G',
        'lat': 0.0,
        'lon': 0.0,
        'timeUtcMs': 1700000000000,
        'staleUtcMs': 1700000300000,
        'receivedUtcMs': 1700000001000,
      };

      final event = TakEvent.fromJson(minimal);
      expect(event.callsign, isNull);
      expect(event.rawPayloadJson, isNull);
    });

    test('toJson round-trips correctly', () {
      final event = TakEvent.fromJson(sampleJson);
      final json = event.toJson();
      final roundTripped = TakEvent.fromJson(json);

      expect(roundTripped.uid, event.uid);
      expect(roundTripped.type, event.type);
      expect(roundTripped.callsign, event.callsign);
      expect(roundTripped.lat, event.lat);
      expect(roundTripped.lon, event.lon);
      expect(roundTripped.timeUtcMs, event.timeUtcMs);
      expect(roundTripped.staleUtcMs, event.staleUtcMs);
      expect(roundTripped.receivedUtcMs, event.receivedUtcMs);
    });

    test('toJsonString produces valid JSON', () {
      final event = TakEvent.fromJson(sampleJson);
      final jsonStr = event.toJsonString();

      // Must parse without throwing
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(parsed['uid'], 'ALPHA-01');
    });

    test('isStale returns true for past stale time', () {
      final staleEvent = TakEvent.fromJson({
        ...sampleJson,
        'staleUtcMs': DateTime.now().millisecondsSinceEpoch - 60000,
      });
      expect(staleEvent.isStale, isTrue);
    });

    test('isStale returns false for future stale time', () {
      final freshEvent = TakEvent.fromJson({
        ...sampleJson,
        'staleUtcMs': DateTime.now().millisecondsSinceEpoch + 300000,
      });
      expect(freshEvent.isStale, isFalse);
    });

    test('displayName returns callsign when present', () {
      final event = TakEvent.fromJson(sampleJson);
      expect(event.displayName, 'ALPHA');
    });

    test('displayName falls back to uid when no callsign', () {
      final event = TakEvent.fromJson({...sampleJson, 'callsign': null});
      expect(event.displayName, 'ALPHA-01');
    });

    group('typeDescription', () {
      test('identifies friendly ground unit', () {
        final event = TakEvent.fromJson({...sampleJson, 'type': 'a-f-G-U-C'});
        expect(event.typeDescription, 'Friendly');
      });

      test('identifies hostile air', () {
        final event = TakEvent.fromJson({...sampleJson, 'type': 'a-h-A'});
        expect(event.typeDescription, 'Hostile');
      });

      test('identifies neutral sea', () {
        final event = TakEvent.fromJson({...sampleJson, 'type': 'a-n-S'});
        expect(event.typeDescription, 'Neutral');
      });

      test('identifies unknown affiliation', () {
        final event = TakEvent.fromJson({...sampleJson, 'type': 'a-u-G'});
        expect(event.typeDescription, 'Unknown');
      });

      test('handles non-atom types gracefully', () {
        final event = TakEvent.fromJson({...sampleJson, 'type': 'b-m-p-s-m'});
        expect(event.typeDescription, 'Bits');
      });
    });

    group('database row conversion', () {
      test('toDbRow produces correct column mapping', () {
        final event = TakEvent.fromJson(sampleJson);
        final row = event.toDbRow();

        expect(row['uid'], 'ALPHA-01');
        expect(row['type'], 'a-f-G-U-C');
        expect(row['callsign'], 'ALPHA');
        expect(row['lat'], 34.0522);
        expect(row['lon'], -118.2437);
        expect(row['time_utc'], 1700000000000);
        expect(row['stale_utc'], 1700000300000);
        expect(row['received_utc'], 1700000001000);
        expect(row['raw_payload_json'], '{"detail":{}}');
      });

      test('fromDbRow parses correct column mapping', () {
        final row = <String, dynamic>{
          'uid': 'CHARLIE-03',
          'type': 'a-n-G',
          'callsign': null,
          'lat': 51.5074,
          'lon': -0.1278,
          'time_utc': 1700000000000,
          'stale_utc': 1700000300000,
          'received_utc': 1700000002000,
          'raw_payload_json': null,
        };

        final event = TakEvent.fromDbRow(row);
        expect(event.uid, 'CHARLIE-03');
        expect(event.type, 'a-n-G');
        expect(event.callsign, isNull);
        expect(event.lat, 51.5074);
        expect(event.lon, -0.1278);
        expect(event.timeUtcMs, 1700000000000);
        expect(event.staleUtcMs, 1700000300000);
        expect(event.receivedUtcMs, 1700000002000);
        expect(event.rawPayloadJson, isNull);
      });

      test('toDbRow and fromDbRow round-trip', () {
        final original = TakEvent.fromJson(sampleJson);
        final restored = TakEvent.fromDbRow(original.toDbRow());

        expect(restored.uid, original.uid);
        expect(restored.type, original.type);
        expect(restored.callsign, original.callsign);
        expect(restored.lat, original.lat);
        expect(restored.lon, original.lon);
        expect(restored.timeUtcMs, original.timeUtcMs);
        expect(restored.staleUtcMs, original.staleUtcMs);
        expect(restored.receivedUtcMs, original.receivedUtcMs);
        expect(restored.rawPayloadJson, original.rawPayloadJson);
      });
    });
  });
}
