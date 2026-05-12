// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D41-A - Cayenne LPP parser byte-vector pins.
//
// The MeshCore firmware emits a small subset of the Cayenne LPP TLV
// format. This file pins:
//   - voltage / temperature / humidity / pressure / GPS round-trip
//     with hand-built byte vectors,
//   - signed temperature works for negative values,
//   - GPS signed 24-bit values sign-extend correctly,
//   - multi-channel grouping is preserved in wire order,
//   - unknown-but-known-size type bytes are tallied + skipped,
//   - unknown un-sized types stop the parse cleanly,
//   - truncated mid-value payloads stop cleanly without throwing,
//   - 0 readings is valid,
//   - max-frame-sized random-ish payload doesn't crash the walker.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_cayenne_lpp.dart';

Uint8List _b(List<int> list) => Uint8List.fromList(list);

void main() {
  final fetchedAt = DateTime(2026, 5, 12, 9, 30);

  group('voltage', () {
    test('decodes 4.05 V (raw u16 = 405 BE)', () {
      // [channel=1][type=116][raw_hi=0x01][raw_lo=0x95]  -> 0x0195 = 405
      final r = parseCayenneLpp(_b([1, 116, 0x01, 0x95]), fetchedAt: fetchedAt);
      expect(r.readings, hasLength(1));
      final v = r.readings.single as MeshCoreTelemetryVoltage;
      expect(v.channel, 1);
      expect(v.volts, closeTo(4.05, 1e-9));
    });

    test('truncated voltage stops cleanly', () {
      // Only 1 of 2 value bytes present.
      final r = parseCayenneLpp(_b([1, 116, 0x01]), fetchedAt: fetchedAt);
      expect(r.readings, isEmpty);
      expect(r.unknownTypes, isEmpty);
    });
  });

  group('temperature', () {
    test('decodes 21.5 °C (raw signed i16 = 215 BE)', () {
      final r = parseCayenneLpp(_b([1, 103, 0x00, 0xD7]), fetchedAt: fetchedAt);
      final t = r.readings.single as MeshCoreTelemetryTemperature;
      expect(t.celsius, closeTo(21.5, 1e-9));
    });

    test('decodes -5.0 °C (raw signed i16 = -50 BE = 0xFFCE)', () {
      final r = parseCayenneLpp(_b([1, 103, 0xFF, 0xCE]), fetchedAt: fetchedAt);
      final t = r.readings.single as MeshCoreTelemetryTemperature;
      expect(t.celsius, closeTo(-5.0, 1e-9));
    });
  });

  group('humidity', () {
    test('decodes 47.0 % (raw u8 = 94)', () {
      final r = parseCayenneLpp(_b([1, 104, 94]), fetchedAt: fetchedAt);
      final h = r.readings.single as MeshCoreTelemetryHumidity;
      expect(h.percent, closeTo(47.0, 1e-9));
    });

    test('decodes 100.0 % (raw u8 = 200)', () {
      final r = parseCayenneLpp(_b([1, 104, 200]), fetchedAt: fetchedAt);
      final h = r.readings.single as MeshCoreTelemetryHumidity;
      expect(h.percent, closeTo(100.0, 1e-9));
    });
  });

  group('pressure', () {
    test('decodes 1013.2 hPa (raw u16 = 10132 BE)', () {
      // 10132 = 0x2794
      final r = parseCayenneLpp(_b([1, 115, 0x27, 0x94]), fetchedAt: fetchedAt);
      final p = r.readings.single as MeshCoreTelemetryPressure;
      expect(p.hPa, closeTo(1013.2, 1e-9));
    });
  });

  group('GPS', () {
    test('positive lat/lon/alt round-trip (24-bit signed BE)', () {
      // lat 47.6062 -> raw 476062 = 0x07439E
      // lon -122.3321 -> raw -1223321
      //                 mod 2^24 = 16777216 - 1223321 = 15553895 = 0xED5567
      // alt 45.0 m * 100 = 4500 = 0x001194
      final r = parseCayenneLpp(
        _b([1, 136, 0x07, 0x43, 0x9E, 0xED, 0x55, 0x67, 0x00, 0x11, 0x94]),
        fetchedAt: fetchedAt,
      );
      final g = r.readings.single as MeshCoreTelemetryGps;
      expect(g.latitude, closeTo(47.6062, 1e-4));
      expect(g.longitude, closeTo(-122.3321, 1e-4));
      expect(g.altitudeMetres, closeTo(45.0, 1e-9));
    });

    test('signed 24-bit floor value (0x800000 -> -8388608)', () {
      // lat raw = 0x800000 -> -8388608 -> -838.8608 °
      // lon = 0x000000 -> 0 -> 0.0 °
      // alt = 0x000000 -> 0 -> 0.0 m
      final r = parseCayenneLpp(
        _b([1, 136, 0x80, 0, 0, 0, 0, 0, 0, 0, 0]),
        fetchedAt: fetchedAt,
      );
      final g = r.readings.single as MeshCoreTelemetryGps;
      expect(g.latitude, closeTo(-838.8608, 1e-4));
      expect(g.longitude, closeTo(0.0, 1e-9));
      expect(g.altitudeMetres, closeTo(0.0, 1e-9));
    });

    test('truncated GPS stops cleanly (8 bytes of 9)', () {
      final r = parseCayenneLpp(
        _b([1, 136, 0, 0, 0, 0, 0, 0, 0, 0]),
        fetchedAt: fetchedAt,
      );
      expect(r.readings, isEmpty);
    });
  });

  group('multi-channel', () {
    test('two channels render in wire order', () {
      // channel 1 voltage 4.05 V, channel 2 humidity 50%, channel 1 temp 20°C
      final r = parseCayenneLpp(
        _b([1, 116, 0x01, 0x95, 2, 104, 100, 1, 103, 0x00, 0xC8]),
        fetchedAt: fetchedAt,
      );
      expect(r.readings, hasLength(3));
      expect(r.readings[0], isA<MeshCoreTelemetryVoltage>());
      expect(r.readings[0].channel, 1);
      expect(r.readings[1], isA<MeshCoreTelemetryHumidity>());
      expect(r.readings[1].channel, 2);
      expect(r.readings[2], isA<MeshCoreTelemetryTemperature>());
      expect(r.readings[2].channel, 1);
    });
  });

  group('unknown types', () {
    test('unknown-but-sized type (e.g. Illuminance=101 size=2) skipped + '
        'tallied', () {
      // [channel=1][type=101 illuminance][2 bytes][type 116 voltage 4.05]
      final r = parseCayenneLpp(
        _b([1, 101, 0xFF, 0xFF, 1, 116, 0x01, 0x95]),
        fetchedAt: fetchedAt,
      );
      expect(r.readings, hasLength(1));
      expect(r.readings.single, isA<MeshCoreTelemetryVoltage>());
      expect(r.unknownTypes[101], 1);
    });

    test(
      'unknown un-sized type stops the parse cleanly (keeps prior reads)',
      () {
        // [voltage][unknown 0x55][would-be-temp]
        final r = parseCayenneLpp(
          _b([1, 116, 0x01, 0x95, 1, 0x55, 1, 103, 0x00, 0xD7]),
          fetchedAt: fetchedAt,
        );
        expect(r.readings, hasLength(1));
        expect(r.readings.single, isA<MeshCoreTelemetryVoltage>());
        expect(r.unknownTypes[0x55], 1);
      },
    );

    test('truncated unknown-but-sized type stops cleanly', () {
      // Illuminance type=101 needs 2 bytes; only 1 supplied.
      final r = parseCayenneLpp(_b([1, 101, 0xFF]), fetchedAt: fetchedAt);
      expect(r.readings, isEmpty);
      expect(r.unknownTypes, isEmpty);
    });
  });

  group('edge cases', () {
    test('zero readings is valid (empty input -> empty response)', () {
      final r = parseCayenneLpp(_b([]), fetchedAt: fetchedAt);
      expect(r.readings, isEmpty);
      expect(r.unknownTypes, isEmpty);
      expect(r.isEmpty, isTrue);
    });

    test('header-only (1 byte) stops cleanly', () {
      final r = parseCayenneLpp(_b([1]), fetchedAt: fetchedAt);
      expect(r.readings, isEmpty);
    });

    test('max-frame-sized payload of voltages does not crash and decodes the '
        'leading entries', () {
      // ~240 byte budget; each voltage record is 4 bytes -> 60 entries.
      final builder = BytesBuilder();
      for (int ch = 0; ch < 60; ch++) {
        builder.add([ch & 0xFF, 116, 0x01, 0x95]);
      }
      final r = parseCayenneLpp(
        Uint8List.fromList(builder.toBytes()),
        fetchedAt: fetchedAt,
      );
      expect(r.readings, hasLength(60));
      expect(r.readings.every((e) => e is MeshCoreTelemetryVoltage), isTrue);
    });
  });

  group('toString redaction sweep', () {
    test('reading toString never embeds raw value or pubkey-shaped hex', () {
      final r = parseCayenneLpp(
        _b([
          1,
          116,
          0x01,
          0x95,
          2,
          103,
          0x00,
          0xD7,
          3,
          104,
          94,
          4,
          115,
          0x27,
          0x94,
        ]),
        fetchedAt: fetchedAt,
      );
      for (final reading in r.readings) {
        final s = reading.toString();
        // No 32 or 64-char hex run.
        expect(RegExp(r'[0-9a-fA-F]{32}').hasMatch(s), isFalse);
        expect(RegExp(r'[0-9a-fA-F]{64}').hasMatch(s), isFalse);
        // No bare decimal sequence of 4+ digits (rough proxy for "raw
        // value leaked"). Channel index is 1 digit, so this is safe.
        expect(RegExp(r'\d{4,}').hasMatch(s), isFalse);
      }
    });
  });
}
