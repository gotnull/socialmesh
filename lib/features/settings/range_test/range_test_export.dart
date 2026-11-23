// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:xml/xml.dart';

import '../../../utils/export_format.dart';
import 'range_test_models.dart';

// Export formats for a recorded Range Test session. The CSV keeps the
// firmware's rangetest.csv columns, in its order, and adds the ones the app
// records beyond it. The KML places each reading at the receiver's position,
// coloured by SNR, so a walk shows where reception held and where it failed.

const String _csvHeader =
    'time,from,sender name,sender lat,sender long,rx lat,rx long,'
    'rx elevation,rx position source,rx snr,rx rssi,via mqtt,distance m,'
    'seq,payload'; // lint-allow: hardcoded-string - CSV header

String rangeTestNodeId(int nodeNum) =>
    '!${nodeNum.toRadixString(16).padLeft(8, '0')}';

/// One row per reading, oldest first. Unknown values are empty cells.
String rangeTestCsv(List<RangeTestReading> readings) {
  final buffer = StringBuffer()..writeln(_csvHeader);
  for (final r in readings) {
    buffer.writeln(
      [
        csvField(r.receivedAt.toUtc().toIso8601String()),
        csvField(rangeTestNodeId(r.senderNodeNum)),
        csvField(r.senderName),
        csvField(r.senderLatitude),
        csvField(r.senderLongitude),
        csvField(r.rxLatitude),
        csvField(r.rxLongitude),
        csvField(r.rxAltitude),
        csvField(r.rxPositionSource?.name),
        csvField(r.rxSnr),
        csvField(r.rxRssi),
        csvField(r.viaMqtt),
        csvField(r.distanceMeters?.round()),
        csvField(r.sequence),
        csvField(r.payload),
      ].join(','),
    );
  }
  return buffer.toString();
}

// SNR bands, matching the NodeDex detail signal colouring. KML colours are
// aabbggrr.
enum _SnrBand {
  good('ff50af4c'),
  fair('ff3bc0ff'),
  weak('ff3643f4'),
  unknown('ff9e9e9e');

  const _SnrBand(this.kmlColor);
  final String kmlColor;

  static _SnrBand of(double? snr) {
    if (snr == null) return unknown;
    if (snr >= 5) return good;
    if (snr >= -5) return fair;
    return weak;
  }
}

String _coordinates(double latitude, double longitude, int? altitude) =>
    '$longitude,$latitude${altitude == null ? '' : ',$altitude'}';

/// A KML document with one placemark per reading that has a receiver
/// position, plus one for each sender's last known position. Readings
/// without a receiver position cannot be placed and are left out.
String rangeTestKml(
  List<RangeTestReading> readings, {
  required String documentName,
}) {
  final builder = XmlBuilder()
    ..processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element(
    'kml',
    nest: () {
      builder.namespace('http://www.opengis.net/kml/2.2');
      builder.element(
        'Document',
        nest: () {
          builder.element('name', nest: documentName);
          for (final band in _SnrBand.values) {
            builder.element(
              'Style',
              attributes: {'id': 'snr-${band.name}'},
              nest: () {
                builder.element(
                  'IconStyle',
                  nest: () => builder.element('color', nest: band.kmlColor),
                );
              },
            );
          }

          final senders = <int, RangeTestReading>{};
          for (final r in readings) {
            if (r.senderLatitude != null && r.senderLongitude != null) {
              senders[r.senderNodeNum] = r;
            }
            final lat = r.rxLatitude;
            final lon = r.rxLongitude;
            if (lat == null || lon == null) continue;
            builder.element(
              'Placemark',
              nest: () {
                builder.element(
                  'name',
                  nest: r.sequence == null ? r.payload : 'seq ${r.sequence}',
                );
                builder.element('description', nest: _describe(r));
                builder.element(
                  'TimeStamp',
                  nest: () => builder.element(
                    'when',
                    nest: r.receivedAt.toUtc().toIso8601String(),
                  ),
                );
                builder.element(
                  'styleUrl',
                  nest: '#snr-${_SnrBand.of(r.rxSnr).name}', // lint-allow: hardcoded-string - KML style id
                );
                builder.element(
                  'Point',
                  nest: () => builder.element(
                    'coordinates',
                    nest: _coordinates(lat, lon, r.rxAltitude),
                  ),
                );
              },
            );
          }

          for (final s in senders.values) {
            builder.element(
              'Placemark',
              nest: () {
                builder.element(
                  'name',
                  nest: s.senderName ?? rangeTestNodeId(s.senderNodeNum),
                );
                builder.element(
                  'Point',
                  nest: () => builder.element(
                    'coordinates',
                    nest: _coordinates(
                      s.senderLatitude!,
                      s.senderLongitude!,
                      null,
                    ),
                  ),
                );
              },
            );
          }
        },
      );
    },
  );
  return builder.buildDocument().toXmlString(pretty: true);
}

String _describe(RangeTestReading r) {
  final parts = <String>[
    r.senderName ?? rangeTestNodeId(r.senderNodeNum),
    if (r.rxSnr != null) 'SNR ${r.rxSnr!.toStringAsFixed(1)} dB',
    if (r.rxRssi != null) 'RSSI ${r.rxRssi} dBm',
    if (r.distanceMeters != null) '${r.distanceMeters!.round()} m',
  ];
  return parts.join(', '); // lint-allow: hardcoded-string - KML description
}
