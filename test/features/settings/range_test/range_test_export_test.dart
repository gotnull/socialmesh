// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/settings/range_test/range_test_export.dart';
import 'package:socialmesh/features/settings/range_test/range_test_models.dart';
import 'package:xml/xml.dart';

RangeTestReading _reading({
  required int packetId,
  int? seq,
  double? snr,
  int? rssi,
  double? rxLat,
  double? rxLon,
  int? rxAlt,
  String? senderName = 'Home',
  String payload = 'seq 1',
  double? senderLat,
  double? senderLon,
  double? distance,
}) => RangeTestReading(
  sessionId: 1,
  receivedAt: DateTime.utc(2026, 11, 24, 9, 0, packetId),
  senderNodeNum: 0x4b5b951c,
  senderName: senderName,
  packetId: packetId,
  sequence: seq,
  payload: payload,
  rxSnr: snr,
  rxRssi: rssi,
  viaMqtt: false,
  rxLatitude: rxLat,
  rxLongitude: rxLon,
  rxAltitude: rxAlt,
  rxPositionSource: rxLat == null ? null : RangeTestPositionSource.phone,
  senderLatitude: senderLat,
  senderLongitude: senderLon,
  distanceMeters: distance,
);

void main() {
  group('rangeTestCsv', () {
    test('writes the header and leaves unknown values empty', () {
      final csv = rangeTestCsv([
        _reading(
          packetId: 1,
          seq: 1,
          snr: -6.5,
          rssi: -101,
          rxLat: -33.86,
          rxLon: 151.2,
          rxAlt: 42,
          senderLat: -33.87,
          senderLon: 151.21,
          distance: 1402.6,
        ),
        _reading(packetId: 2, seq: 2),
      ]);
      expect(csv.split('\n'), [
        'time,from,sender name,sender lat,sender long,rx lat,rx long,'
            'rx elevation,rx position source,rx snr,rx rssi,via mqtt,'
            'distance m,seq,payload',
        '2026-11-24T09:00:01.000Z,!4b5b951c,Home,-33.87,151.21,-33.86,'
            '151.2,42,phone,-6.5,-101,false,1403,1,seq 1',
        '2026-11-24T09:00:02.000Z,!4b5b951c,Home,,,,,,,,,false,,2,seq 1',
        '',
      ]);
    });

    test('quotes names and payloads that would break a row', () {
      final csv = rangeTestCsv([
        _reading(packetId: 1, senderName: 'Hill, "North"', payload: 'a\nb'),
      ]);
      expect(csv, contains('"Hill, ""North"""'));
      expect(csv, contains('"a\nb"'));
    });
  });

  group('rangeTestKml', () {
    test('places readings with a receiver position, coloured by SNR', () {
      final kml = rangeTestKml([
        _reading(packetId: 1, seq: 1, snr: 7, rxLat: -33.86, rxLon: 151.2),
        _reading(packetId: 2, seq: 2, snr: -2, rxLat: -33.861, rxLon: 151.2),
        _reading(packetId: 3, seq: 3, snr: -12, rxLat: -33.862, rxLon: 151.2),
        _reading(packetId: 4, seq: 4, rxLat: -33.863, rxLon: 151.2, rxAlt: 9),
        _reading(packetId: 5, seq: 5, snr: 3),
      ], documentName: 'Range test <24th Nov>');

      final doc = XmlDocument.parse(kml);
      expect(
        doc.findAllElements('name').first.innerText,
        'Range test <24th Nov>',
      );
      final placemarks = doc.findAllElements('Placemark').toList();
      expect(placemarks, hasLength(4));
      expect(placemarks.map((p) => p.getElement('styleUrl')!.innerText), [
        '#snr-good',
        '#snr-fair',
        '#snr-weak',
        '#snr-unknown',
      ]);
      expect(
        placemarks.first.findAllElements('coordinates').single.innerText,
        '151.2,-33.86',
      );
      expect(
        placemarks.last.findAllElements('coordinates').single.innerText,
        '151.2,-33.863,9',
      );
      expect(placemarks.first.getElement('name')!.innerText, 'seq 1');
    });

    test('adds each sender at its last known position', () {
      final kml = rangeTestKml([
        _reading(packetId: 1, rxLat: 1, rxLon: 2, senderLat: 5, senderLon: 6),
        _reading(packetId: 2, rxLat: 1, rxLon: 2, senderLat: 7, senderLon: 8),
      ], documentName: 'x');
      final placemarks = XmlDocument.parse(kml)
          .findAllElements('Placemark')
          .toList();
      expect(placemarks, hasLength(3));
      expect(placemarks.last.getElement('name')!.innerText, 'Home');
      expect(
        placemarks.last.findAllElements('coordinates').single.innerText,
        '8.0,7.0',
      );
    });
  });
}
