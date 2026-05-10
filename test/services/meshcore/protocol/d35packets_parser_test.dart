// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D35-PACKETS-A: `MeshCorePacketsStats.parse` byte-vector regression
// pins.
//
// Wire layout (30 bytes total):
//   offset  field              type      notes
//   0       resp_code          u8 = 0x18 RESP_CODE_STATS
//   1       stats_type         u8 = 2    STATS_TYPE_PACKETS
//   2-5     packets_received   u32 LE
//   6-9     packets_sent       u32 LE
//   10-13   sent_flood         u32 LE
//   14-17   sent_direct        u32 LE
//   18-21   recv_flood         u32 LE
//   22-25   recv_direct        u32 LE
//   26-29   recv_errors        u32 LE

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

/// Build a 30-byte PACKETS payload from typed components.
Uint8List _buildPayload({
  int respCode = 0x18,
  int subtype = 2,
  int packetsReceived = 0,
  int packetsSent = 0,
  int sentFlood = 0,
  int sentDirect = 0,
  int recvFlood = 0,
  int recvDirect = 0,
  int recvErrors = 0,
}) {
  final bytes = Uint8List(30);
  final bd = ByteData.sublistView(bytes);
  bytes[0] = respCode;
  bytes[1] = subtype;
  bd.setUint32(2, packetsReceived, Endian.little);
  bd.setUint32(6, packetsSent, Endian.little);
  bd.setUint32(10, sentFlood, Endian.little);
  bd.setUint32(14, sentDirect, Endian.little);
  bd.setUint32(18, recvFlood, Endian.little);
  bd.setUint32(22, recvDirect, Endian.little);
  bd.setUint32(26, recvErrors, Endian.little);
  return bytes;
}

void main() {
  group('MeshCorePacketsStats.parse - D35-PACKETS-A', () {
    test('parses a full PACKETS payload with all seven counters', () {
      final now = DateTime(2026, 5, 11, 12);
      final payload = _buildPayload(
        packetsReceived: 1247,
        packetsSent: 892,
        sentFlood: 34,
        sentDirect: 858,
        recvFlood: 412,
        recvDirect: 830,
        recvErrors: 3,
      );
      final stats = MeshCorePacketsStats.parse(payload, now: now);
      expect(stats, isNotNull);
      expect(stats!.packetsReceived, 1247);
      expect(stats.packetsSent, 892);
      expect(stats.sentFlood, 34);
      expect(stats.sentDirect, 858);
      expect(stats.recvFlood, 412);
      expect(stats.recvDirect, 830);
      expect(stats.recvErrors, 3);
      expect(stats.fetchedAt, now);
    });

    test('all seven fields land at the correct offsets - swap each '
        'field to a unique value and confirm the assignment', () {
      // Use distinct prime-ish values per field so a parser bug
      // that swaps two offsets fails loudly.
      final payload = _buildPayload(
        packetsReceived: 11,
        packetsSent: 22,
        sentFlood: 33,
        sentDirect: 44,
        recvFlood: 55,
        recvDirect: 66,
        recvErrors: 77,
      );
      final stats = MeshCorePacketsStats.parse(payload);
      expect(stats!.packetsReceived, 11);
      expect(stats.packetsSent, 22);
      expect(stats.sentFlood, 33);
      expect(stats.sentDirect, 44);
      expect(stats.recvFlood, 55);
      expect(stats.recvDirect, 66);
      expect(stats.recvErrors, 77);
    });

    test('u32 boundary values parse safely without sign-wraparound', () {
      // 2^31 = 2147483648 - the boundary an accidental getInt32 would
      // read as a large negative number. Use it for every counter.
      const big = 2147483648;
      final payload = _buildPayload(
        packetsReceived: big,
        packetsSent: big + 1,
        sentFlood: big + 2,
        sentDirect: big + 3,
        recvFlood: big + 4,
        recvDirect: big + 5,
        recvErrors: big + 6,
      );
      final stats = MeshCorePacketsStats.parse(payload);
      expect(stats!.packetsReceived, big);
      expect(stats.packetsSent, big + 1);
      expect(stats.sentFlood, big + 2);
      expect(stats.sentDirect, big + 3);
      expect(stats.recvFlood, big + 4);
      expect(stats.recvDirect, big + 5);
      expect(stats.recvErrors, big + 6);
    });

    test('rejects payloads of wrong length', () {
      // 29 bytes (truncated).
      expect(
        MeshCorePacketsStats.parse(Uint8List(29)),
        isNull,
        reason: '29-byte truncated frame must be rejected',
      );
      // 31 bytes (over).
      expect(
        MeshCorePacketsStats.parse(Uint8List(31)),
        isNull,
        reason: '31-byte over-length frame must be rejected',
      );
      // 0 bytes.
      expect(MeshCorePacketsStats.parse(Uint8List(0)), isNull);
      // RADIO-shaped 14 bytes.
      expect(
        MeshCorePacketsStats.parse(Uint8List(14)),
        isNull,
        reason: '14-byte RADIO-shaped payload must be rejected by length',
      );
      // CORE-shaped 11 bytes.
      expect(
        MeshCorePacketsStats.parse(Uint8List(11)),
        isNull,
        reason: '11-byte CORE-shaped payload must be rejected by length',
      );
    });

    test('rejects wrong discriminator (resp_code != 0x18)', () {
      final payload = _buildPayload(respCode: 0x05); // self-info code
      expect(MeshCorePacketsStats.parse(payload), isNull);
    });

    test('rejects wrong subtype (stats_type != STATS_TYPE_PACKETS=2)', () {
      // RADIO subtype.
      final radio = _buildPayload(subtype: 1);
      expect(MeshCorePacketsStats.parse(radio), isNull);
      // CORE subtype.
      final core = _buildPayload(subtype: 0);
      expect(MeshCorePacketsStats.parse(core), isNull);
      // Bogus subtype.
      final bogus = _buildPayload(subtype: 0xFF);
      expect(MeshCorePacketsStats.parse(bogus), isNull);
    });

    test('parser falls back to DateTime.now() when caller omits now', () {
      final payload = _buildPayload();
      final before = DateTime.now();
      final stats = MeshCorePacketsStats.parse(payload);
      final after = DateTime.now();
      expect(stats, isNotNull);
      expect(stats!.fetchedAt.isBefore(before), isFalse);
      expect(stats.fetchedAt.isAfter(after), isFalse);
    });

    test('toString redacts to safe summary - typed counts only, no '
        'raw payload bytes', () {
      final payload = _buildPayload(
        packetsReceived: 1247,
        packetsSent: 892,
        sentFlood: 34,
        sentDirect: 858,
        recvFlood: 412,
        recvDirect: 830,
        recvErrors: 3,
      );
      final stats = MeshCorePacketsStats.parse(payload);
      final text = stats.toString();
      // Allowed tokens.
      expect(text, contains('rx=1247'));
      expect(text, contains('tx=892'));
      expect(text, contains('tx_flood=34'));
      expect(text, contains('tx_direct=858'));
      expect(text, contains('rx_flood=412'));
      expect(text, contains('rx_direct=830'));
      expect(text, contains('rx_err=3'));
      // No long hex run that could be confused with payload bytes.
      expect(text, isNot(matches(r'[0-9a-f]{14,}')));
    });
  });
}
