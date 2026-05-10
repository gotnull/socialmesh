// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D35-B-A: `MeshCoreCoreStats.parse` byte-vector regression pins.
//
// Wire layout (11 bytes total):
//   offset  field            type      notes
//   0       resp_code        u8 = 0x18 RESP_CODE_STATS
//   1       stats_type       u8 = 0    STATS_TYPE_CORE
//   2-3     battery_mv       u16 LE    millivolts
//   4-7     uptime_secs      u32 LE    seconds since power-on
//   8-9     error_flags      u16 LE    firmware-internal accumulator
//   10      queue_len        u8        outbound LoRa TX queue depth

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

/// Build an 11-byte CORE-subtype stats payload from typed components.
Uint8List _buildPayload({
  int respCode = 0x18,
  int subtype = 0,
  int batteryMv = 3700,
  int uptimeSecs = 0,
  int errorFlags = 0,
  int queueLen = 0,
}) {
  final bytes = Uint8List(11);
  final bd = ByteData.sublistView(bytes);
  bytes[0] = respCode;
  bytes[1] = subtype;
  bd.setUint16(2, batteryMv, Endian.little);
  bd.setUint32(4, uptimeSecs, Endian.little);
  bd.setUint16(8, errorFlags, Endian.little);
  bytes[10] = queueLen;
  return bytes;
}

void main() {
  group('MeshCoreCoreStats.parse - D35-B-A', () {
    test('parses a full CORE payload with battery, uptime, queue, and '
        'error flags', () {
      final now = DateTime(2026, 5, 11, 12);
      final payload = _buildPayload(
        batteryMv: 4012,
        uptimeSecs: 3661, // 1 h 1 m 1 s
        errorFlags: 0x0042,
        queueLen: 7,
      );
      final stats = MeshCoreCoreStats.parse(payload, now: now);
      expect(stats, isNotNull);
      expect(stats!.batteryMillivolts, 4012);
      expect(stats.uptime, const Duration(seconds: 3661));
      expect(stats.errorFlags, 0x0042);
      expect(stats.queueLength, 7);
      expect(stats.fetchedAt, now);
    });

    test('u16 LE battery parses across the typical LiPo range', () {
      final lo = MeshCoreCoreStats.parse(_buildPayload(batteryMv: 3000));
      final hi = MeshCoreCoreStats.parse(_buildPayload(batteryMv: 4200));
      expect(lo!.batteryMillivolts, 3000);
      expect(hi!.batteryMillivolts, 4200);
    });

    test('u32 LE uptime parses to Duration in seconds', () {
      final stats = MeshCoreCoreStats.parse(
        _buildPayload(uptimeSecs: 86400),
      ); // exactly 1 day
      expect(stats!.uptime.inSeconds, 86400);
      expect(stats.uptime.inHours, 24);
    });

    test('large u32 uptime does not sign-wrap', () {
      // 2^31 = 2147483648 seconds (~68 years). Pre-D35-B parser would
      // mis-read this as a negative i32 if it accidentally used getInt32.
      const big = 2147483648;
      final stats = MeshCoreCoreStats.parse(_buildPayload(uptimeSecs: big));
      expect(stats!.uptime.inSeconds, big);
    });

    test('u16 LE error flags parses raw value across the range', () {
      final zero = MeshCoreCoreStats.parse(_buildPayload(errorFlags: 0));
      final mid = MeshCoreCoreStats.parse(_buildPayload(errorFlags: 0x0042));
      final hi = MeshCoreCoreStats.parse(_buildPayload(errorFlags: 0xFFFF));
      expect(zero!.errorFlags, 0);
      expect(mid!.errorFlags, 0x0042);
      expect(hi!.errorFlags, 0xFFFF);
    });

    test('u8 queue length parses 0..255', () {
      final zero = MeshCoreCoreStats.parse(_buildPayload(queueLen: 0));
      final mid = MeshCoreCoreStats.parse(_buildPayload(queueLen: 42));
      final hi = MeshCoreCoreStats.parse(_buildPayload(queueLen: 255));
      expect(zero!.queueLength, 0);
      expect(mid!.queueLength, 42);
      expect(hi!.queueLength, 255);
    });

    test('rejects payloads of wrong length', () {
      expect(
        MeshCoreCoreStats.parse(Uint8List(10)),
        isNull,
        reason: '10-byte truncated frame must be rejected',
      );
      expect(
        MeshCoreCoreStats.parse(Uint8List(12)),
        isNull,
        reason: '12-byte over-length frame must be rejected',
      );
      expect(
        MeshCoreCoreStats.parse(Uint8List(0)),
        isNull,
        reason: 'empty frame must be rejected',
      );
      // RADIO subtype response is 14 bytes; if a RADIO payload leaked
      // into the CORE parse path the length check must catch it.
      expect(
        MeshCoreCoreStats.parse(Uint8List(14)),
        isNull,
        reason: '14-byte RADIO-shaped payload must be rejected by length',
      );
    });

    test('rejects wrong discriminator (resp_code != 0x18)', () {
      final payload = _buildPayload(respCode: 0x05); // self-info code
      expect(MeshCoreCoreStats.parse(payload), isNull);
    });

    test('rejects wrong subtype (stats_type != STATS_TYPE_CORE=0)', () {
      // RADIO subtype.
      final radio = _buildPayload(subtype: 1);
      expect(MeshCoreCoreStats.parse(radio), isNull);
      // PACKETS subtype.
      final packets = _buildPayload(subtype: 2);
      expect(MeshCoreCoreStats.parse(packets), isNull);
      // Bogus subtype.
      final bogus = _buildPayload(subtype: 0xFF);
      expect(MeshCoreCoreStats.parse(bogus), isNull);
    });

    test('parser falls back to DateTime.now() when caller omits now', () {
      final payload = _buildPayload();
      final before = DateTime.now();
      final stats = MeshCoreCoreStats.parse(payload);
      final after = DateTime.now();
      expect(stats, isNotNull);
      expect(stats!.fetchedAt.isBefore(before), isFalse);
      expect(stats.fetchedAt.isAfter(after), isFalse);
    });

    test('toString redacts to safe summary - no raw payload bytes', () {
      final payload = _buildPayload(
        batteryMv: 4012,
        uptimeSecs: 3661,
        errorFlags: 0x0042,
        queueLen: 7,
      );
      final stats = MeshCoreCoreStats.parse(payload);
      final text = stats.toString();
      // Allowed tokens.
      expect(text, contains('uptime='));
      expect(text, contains('q=7'));
      expect(text, contains('err_flags=0x0042'));
      // No long hex run that could be confused with payload bytes.
      expect(text, isNot(matches(r'[0-9a-f]{14,}')));
    });
  });
}
