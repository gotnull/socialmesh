// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D35-A - `MeshCoreRadioStats.parse` byte-vector regression pins.
//
// Wire layout (14 bytes total):
//   offset  field            type      notes
//   0       resp_code        u8 = 0x18 RESP_CODE_STATS
//   1       stats_type       u8 = 1    STATS_TYPE_RADIO
//   2-3     noise_floor      i16 LE    dBm
//   4       last_rssi        i8        dBm
//   5       last_snr_raw     i8        quarter-dB (raw / 4 = dB)
//   6-9     tx_air_secs      u32 LE    cumulative TX airtime, seconds
//   10-13   rx_air_secs      u32 LE    cumulative RX airtime, seconds

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

/// Build a 14-byte RADIO-subtype stats payload from typed components.
Uint8List _buildPayload({
  int respCode = 0x18,
  int subtype = 1,
  int noise = -110,
  int rssi = -83,
  int snrQuarter = 30, // 7.5 dB
  int txSecs = 0,
  int rxSecs = 0,
}) {
  final bytes = Uint8List(14);
  final bd = ByteData.sublistView(bytes);
  bytes[0] = respCode;
  bytes[1] = subtype;
  bd.setInt16(2, noise, Endian.little);
  bd.setInt8(4, rssi);
  bd.setInt8(5, snrQuarter);
  bd.setUint32(6, txSecs, Endian.little);
  bd.setUint32(10, rxSecs, Endian.little);
  return bytes;
}

void main() {
  group('MeshCoreRadioStats.parse - D35-A', () {
    test('parses a full RADIO payload with negative noise / RSSI and '
        'positive SNR quarter-dB', () {
      final now = DateTime(2026, 5, 10, 12);
      final payload = _buildPayload(
        noise: -110,
        rssi: -83,
        snrQuarter: 30, // 7.5 dB
        txSecs: 1234,
        rxSecs: 5678,
      );
      final stats = MeshCoreRadioStats.parse(payload, now: now);
      expect(stats, isNotNull);
      expect(stats!.noiseFloorDbm, -110);
      expect(stats.lastRssiDbm, -83);
      expect(stats.lastSnrQuarter, 30);
      expect(stats.snrDb, 7.5);
      expect(stats.txAirtime, const Duration(seconds: 1234));
      expect(stats.rxAirtime, const Duration(seconds: 5678));
      expect(stats.fetchedAt, now);
    });

    test('signed int16 noise floor parses negative values that span '
        'the full range', () {
      // -32000 dBm is unphysical but tests the i16 boundary.
      final payload = _buildPayload(noise: -32000);
      final stats = MeshCoreRadioStats.parse(payload);
      expect(stats, isNotNull);
      expect(stats!.noiseFloorDbm, -32000);
    });

    test('signed int8 RSSI parses negative values across the full range', () {
      final payload = _buildPayload(rssi: -128);
      final stats = MeshCoreRadioStats.parse(payload);
      expect(stats, isNotNull);
      expect(stats!.lastRssiDbm, -128);
    });

    test('signed int8 SNR quarter-dB derives snrDb = raw / 4.0 with '
        'negative values', () {
      final payload = _buildPayload(snrQuarter: -8); // -2.0 dB
      final stats = MeshCoreRadioStats.parse(payload);
      expect(stats, isNotNull);
      expect(stats!.lastSnrQuarter, -8);
      expect(stats.snrDb, -2.0);
    });

    test('uint32 TX/RX airtime parses to Duration in seconds', () {
      final payload = _buildPayload(txSecs: 3600, rxSecs: 7200);
      final stats = MeshCoreRadioStats.parse(payload);
      expect(stats!.txAirtime.inSeconds, 3600);
      expect(stats.rxAirtime.inSeconds, 7200);
      expect(stats.txAirtime.inHours, 1);
      expect(stats.rxAirtime.inHours, 2);
    });

    test('uint32 TX airtime can hold large values (~136 years) without '
        'sign-extension wraparound', () {
      // Pick a value above 0x80000000 to confirm we treat as unsigned.
      const big = 0x80000000; // 2^31
      final payload = _buildPayload(txSecs: big);
      final stats = MeshCoreRadioStats.parse(payload);
      expect(stats!.txAirtime.inSeconds, big);
    });

    test('rejects payloads of wrong length', () {
      // 13 bytes (truncated)
      expect(
        MeshCoreRadioStats.parse(Uint8List(13)),
        isNull,
        reason: '13-byte truncated frame must be rejected',
      );
      // 15 bytes (over)
      expect(
        MeshCoreRadioStats.parse(Uint8List(15)),
        isNull,
        reason: '15-byte over-length frame must be rejected',
      );
      // 0 bytes
      expect(
        MeshCoreRadioStats.parse(Uint8List(0)),
        isNull,
        reason: 'empty frame must be rejected',
      );
    });

    test('rejects wrong discriminator (resp_code != 0x18)', () {
      final payload = _buildPayload(respCode: 0x05); // self-info code
      expect(MeshCoreRadioStats.parse(payload), isNull);
    });

    test('rejects wrong subtype (stats_type != STATS_TYPE_RADIO=1)', () {
      // CORE subtype.
      final coreSubtype = _buildPayload(subtype: 0);
      expect(MeshCoreRadioStats.parse(coreSubtype), isNull);
      // PACKETS subtype.
      final packetsSubtype = _buildPayload(subtype: 2);
      expect(MeshCoreRadioStats.parse(packetsSubtype), isNull);
      // Bogus subtype.
      final bogusSubtype = _buildPayload(subtype: 0xFF);
      expect(MeshCoreRadioStats.parse(bogusSubtype), isNull);
    });

    test('parser falls back to DateTime.now() when caller omits now', () {
      final payload = _buildPayload();
      final before = DateTime.now();
      final stats = MeshCoreRadioStats.parse(payload);
      final after = DateTime.now();
      expect(stats, isNotNull);
      expect(stats!.fetchedAt.isBefore(before), isFalse);
      expect(stats.fetchedAt.isAfter(after), isFalse);
    });

    test('toString redacts to safe summary (no raw payload bytes)', () {
      final payload = _buildPayload(noise: -110, rssi: -83, snrQuarter: 30);
      final stats = MeshCoreRadioStats.parse(payload);
      final text = stats.toString();
      // Must NOT contain a hex run that could be confused with payload
      // bytes; only typed numeric values + units.
      expect(text, contains('noise=-110'));
      expect(text, contains('rssi=-83'));
      expect(text, contains('snr_q=30'));
      expect(text, isNot(matches(r'[0-9a-f]{14,}')));
    });
  });
}
