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

    group('motion data fields', () {
      test('fromJson parses speed, course, hae when present', () {
        final json = <String, dynamic>{
          ...sampleJson,
          'speed': 12.5,
          'course': 45.0,
          'hae': 152.3,
        };
        final event = TakEvent.fromJson(json);
        expect(event.speed, 12.5);
        expect(event.course, 45.0);
        expect(event.hae, 152.3);
      });

      test('fromJson handles null motion fields', () {
        final event = TakEvent.fromJson(sampleJson);
        expect(event.speed, isNull);
        expect(event.course, isNull);
        expect(event.hae, isNull);
      });

      test('toJson includes motion fields when present', () {
        final event = TakEvent(
          uid: 'TEST',
          type: 'a-f-G-U-C',
          lat: 34.0,
          lon: -118.0,
          timeUtcMs: 1700000000000,
          staleUtcMs: 1700000300000,
          receivedUtcMs: 1700000001000,
          speed: 25.0,
          course: 90.0,
          hae: 300.0,
        );
        final json = event.toJson();
        expect(json['speed'], 25.0);
        expect(json['course'], 90.0);
        expect(json['hae'], 300.0);
      });

      test('toJson omits motion fields when null', () {
        final event = TakEvent.fromJson(sampleJson);
        final json = event.toJson();
        expect(json.containsKey('speed'), isFalse);
        expect(json.containsKey('course'), isFalse);
        expect(json.containsKey('hae'), isFalse);
      });

      test('fromDbRow and toDbRow round-trip motion fields', () {
        final event = TakEvent(
          uid: 'MOTION-01',
          type: 'a-f-A-M-F',
          lat: 37.0,
          lon: -122.0,
          timeUtcMs: 1700000000000,
          staleUtcMs: 1700000300000,
          receivedUtcMs: 1700000001000,
          speed: 50.0,
          course: 270.0,
          hae: 5000.0,
        );
        final restored = TakEvent.fromDbRow(event.toDbRow());
        expect(restored.speed, 50.0);
        expect(restored.course, 270.0);
        expect(restored.hae, 5000.0);
      });

      test('fromDbRow handles null motion columns', () {
        final row = <String, dynamic>{
          'uid': 'NULL-MOTION',
          'type': 'a-f-G',
          'callsign': null,
          'lat': 0.0,
          'lon': 0.0,
          'time_utc': 1700000000000,
          'stale_utc': 1700000300000,
          'received_utc': 1700000001000,
          'raw_payload_json': null,
          'speed': null,
          'course': null,
          'hae': null,
        };
        final event = TakEvent.fromDbRow(row);
        expect(event.speed, isNull);
        expect(event.course, isNull);
        expect(event.hae, isNull);
      });

      test('hasMotionData returns true when any field is set', () {
        final withSpeed = TakEvent(
          uid: 'A',
          type: 'a-f-G',
          lat: 0,
          lon: 0,
          timeUtcMs: 0,
          staleUtcMs: 0,
          receivedUtcMs: 0,
          speed: 10.0,
        );
        expect(withSpeed.hasMotionData, isTrue);

        final withHae = TakEvent(
          uid: 'B',
          type: 'a-f-G',
          lat: 0,
          lon: 0,
          timeUtcMs: 0,
          staleUtcMs: 0,
          receivedUtcMs: 0,
          hae: 100.0,
        );
        expect(withHae.hasMotionData, isTrue);
      });

      test('hasMotionData returns false when no fields set', () {
        final noMotion = TakEvent.fromJson(sampleJson);
        expect(noMotion.hasMotionData, isFalse);
      });

      test('formattedSpeed returns Stationary for null or zero', () {
        final event = TakEvent.fromJson(sampleJson);
        expect(event.formattedSpeed, 'Stationary');

        final zeroSpeed = TakEvent(
          uid: 'Z',
          type: 'a-f-G',
          lat: 0,
          lon: 0,
          timeUtcMs: 0,
          staleUtcMs: 0,
          receivedUtcMs: 0,
          speed: 0.0,
        );
        expect(zeroSpeed.formattedSpeed, 'Stationary');
      });

      test('formattedSpeed formats km/h and knots', () {
        final event = TakEvent(
          uid: 'S',
          type: 'a-f-G',
          lat: 0,
          lon: 0,
          timeUtcMs: 0,
          staleUtcMs: 0,
          receivedUtcMs: 0,
          speed: 10.0, // 36 km/h, 19.4 kn
        );
        expect(event.formattedSpeed, '36.0 km/h (19.4 kn)');
      });

      test('formattedCourse returns degrees and compass direction', () {
        final north = TakEvent(
          uid: 'N',
          type: 'a-f-G',
          lat: 0,
          lon: 0,
          timeUtcMs: 0,
          staleUtcMs: 0,
          receivedUtcMs: 0,
          course: 0.0,
        );
        expect(north.formattedCourse, '000\u00B0 (N)');

        final east = TakEvent(
          uid: 'E',
          type: 'a-f-G',
          lat: 0,
          lon: 0,
          timeUtcMs: 0,
          staleUtcMs: 0,
          receivedUtcMs: 0,
          course: 90.0,
        );
        expect(east.formattedCourse, '090\u00B0 (E)');

        final sw = TakEvent(
          uid: 'SW',
          type: 'a-f-G',
          lat: 0,
          lon: 0,
          timeUtcMs: 0,
          staleUtcMs: 0,
          receivedUtcMs: 0,
          course: 225.0,
        );
        expect(sw.formattedCourse, '225\u00B0 (SW)');
      });

      test('formattedCourse returns null when course is null', () {
        final event = TakEvent.fromJson(sampleJson);
        expect(event.formattedCourse, isNull);
      });

      test('formattedAltitude formats meters and feet', () {
        final event = TakEvent(
          uid: 'A',
          type: 'a-f-G',
          lat: 0,
          lon: 0,
          timeUtcMs: 0,
          staleUtcMs: 0,
          receivedUtcMs: 0,
          hae: 152.3,
        );
        // 152.3 m = ~500 ft
        expect(event.formattedAltitude, '152 m (500 ft)');
      });

      test('formattedAltitude returns null when hae is null', () {
        final event = TakEvent.fromJson(sampleJson);
        expect(event.formattedAltitude, isNull);
      });
    });
  });
}
