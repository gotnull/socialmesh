// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D36-A: `MeshCoreNeighborsResponse.parse` byte-vector regression pins.
//
// Wire layout:
//   offset  field             type      notes
//   0-1     reportedCount     u16 LE
//   2-3     resultsCount      u16 LE
//   4+      N × 7-byte neighbour records:
//     [0..3]  pubkey_prefix   raw 4 bytes
//     [4..7]  lastHeardSecs   u32 LE
//     [8]     snrRaw          i8

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

Uint8List _buildPayload({
  int reportedCount = 0,
  required List<({Uint8List prefix, int lastHeardSecs, int snrRaw})> rows,
}) {
  final body = BytesBuilder();
  final header = ByteData(4)
    ..setUint16(0, reportedCount, Endian.little)
    ..setUint16(2, rows.length, Endian.little);
  body.add(header.buffer.asUint8List());
  for (final r in rows) {
    if (r.prefix.length != 4) {
      throw ArgumentError('test fixture: prefix must be 4 bytes');
    }
    body.add(r.prefix);
    final rec = ByteData(5)
      ..setUint32(0, r.lastHeardSecs, Endian.little)
      ..setInt8(4, r.snrRaw);
    body.add(rec.buffer.asUint8List());
  }
  return body.toBytes();
}

void main() {
  group('MeshCoreNeighborsResponse.parse - D36-A', () {
    test('parses a 0-neighbour response (header only)', () {
      final now = DateTime(2026, 5, 11, 12);
      final payload = _buildPayload(reportedCount: 0, rows: []);
      final parsed = MeshCoreNeighborsResponse.parse(payload, now: now);
      expect(parsed, isNotNull);
      expect(parsed!.reportedCount, 0);
      expect(parsed.results, isEmpty);
      expect(parsed.fetchedAt, now);
    });

    test('parses a 1-neighbour response with the record at offset 4', () {
      final now = DateTime(2026, 5, 11, 12);
      final payload = _buildPayload(
        reportedCount: 1,
        rows: [
          (
            prefix: Uint8List.fromList([0xAB, 0x12, 0xCD, 0x34]),
            lastHeardSecs: 83,
            snrRaw: 25, // 6.25 dB
          ),
        ],
      );
      final parsed = MeshCoreNeighborsResponse.parse(payload, now: now);
      expect(parsed, isNotNull);
      expect(parsed!.reportedCount, 1);
      expect(parsed.results, hasLength(1));
      expect(
        parsed.results.first.pubKeyPrefix,
        equals(Uint8List.fromList([0xAB, 0x12, 0xCD, 0x34])),
      );
      expect(parsed.results.first.lastHeard, const Duration(seconds: 83));
      expect(parsed.results.first.snrQuarter, 25);
      expect(parsed.results.first.snrDb, 6.25);
    });

    test('parses a 15-neighbour response (the meshcore-open cap)', () {
      final rows = List.generate(
        15,
        (i) => (
          prefix: Uint8List.fromList([i + 1, 0, 0, 0]),
          lastHeardSecs: 1000 + i,
          snrRaw: -8 + i,
        ),
      );
      final payload = _buildPayload(reportedCount: 15, rows: rows);
      final parsed = MeshCoreNeighborsResponse.parse(payload);
      expect(parsed, isNotNull);
      expect(parsed!.results, hasLength(15));
      for (var i = 0; i < 15; i++) {
        expect(parsed.results[i].pubKeyPrefix.first, i + 1);
        expect(parsed.results[i].lastHeard.inSeconds, 1000 + i);
        expect(parsed.results[i].snrQuarter, -8 + i);
      }
    });

    test('reportedCount > resultsCount is accepted (partial response)', () {
      final payload = _buildPayload(
        reportedCount: 42, // repeater claims 42 neighbours total
        rows: List.generate(
          15,
          (i) => (
            prefix: Uint8List.fromList([i, 0, 0, 0]),
            lastHeardSecs: 0,
            snrRaw: 0,
          ),
        ),
      );
      final parsed = MeshCoreNeighborsResponse.parse(payload);
      expect(parsed, isNotNull);
      expect(parsed!.reportedCount, 42);
      expect(parsed.results, hasLength(15));
    });

    test('u32 lastHeardSecs at 2^31 boundary parses without sign-wrap', () {
      const big = 2147483648;
      final payload = _buildPayload(
        reportedCount: 1,
        rows: [
          (
            prefix: Uint8List.fromList([0, 0, 0, 0]),
            lastHeardSecs: big,
            snrRaw: 0,
          ),
        ],
      );
      final parsed = MeshCoreNeighborsResponse.parse(payload);
      expect(parsed!.results.first.lastHeard.inSeconds, big);
    });

    test('snrRaw signed i8 spans -128..127', () {
      final payload = _buildPayload(
        reportedCount: 2,
        rows: [
          (
            prefix: Uint8List.fromList([1, 2, 3, 4]),
            lastHeardSecs: 0,
            snrRaw: -128,
          ),
          (
            prefix: Uint8List.fromList([5, 6, 7, 8]),
            lastHeardSecs: 0,
            snrRaw: 127,
          ),
        ],
      );
      final parsed = MeshCoreNeighborsResponse.parse(payload);
      expect(parsed!.results[0].snrQuarter, -128);
      expect(parsed.results[1].snrQuarter, 127);
      expect(parsed.results[0].snrDb, -32.0);
      expect(parsed.results[1].snrDb, 31.75);
    });

    test('rejects mismatched length (declared > actual records)', () {
      // Header says 2 records, body only has bytes for 1 record.
      final header = Uint8List(4);
      ByteData.sublistView(header)
        ..setUint16(0, 2, Endian.little)
        ..setUint16(2, 2, Endian.little);
      final partial = Uint8List(4 + 7); // only one 7-byte record
      partial.setRange(0, 4, header);
      expect(MeshCoreNeighborsResponse.parse(partial), isNull);
    });

    test('rejects mismatched length (declared < actual records)', () {
      // Header says 0 records but tail bytes remain.
      final header = Uint8List(4);
      ByteData.sublistView(header)
        ..setUint16(0, 0, Endian.little)
        ..setUint16(2, 0, Endian.little);
      final extra = Uint8List(4 + 7); // 7 trailing bytes claim no row
      extra.setRange(0, 4, header);
      expect(MeshCoreNeighborsResponse.parse(extra), isNull);
    });

    test('rejects empty / truncated payloads', () {
      expect(MeshCoreNeighborsResponse.parse(Uint8List(0)), isNull);
      expect(MeshCoreNeighborsResponse.parse(Uint8List(1)), isNull);
      expect(MeshCoreNeighborsResponse.parse(Uint8List(3)), isNull);
    });

    test('parser falls back to DateTime.now() when caller omits now', () {
      final payload = _buildPayload(reportedCount: 0, rows: []);
      final before = DateTime.now();
      final parsed = MeshCoreNeighborsResponse.parse(payload);
      final after = DateTime.now();
      expect(parsed, isNotNull);
      expect(parsed!.fetchedAt.isBefore(before), isFalse);
      expect(parsed.fetchedAt.isAfter(after), isFalse);
    });

    test('toString redacts - counts only, no prefix bytes', () {
      final payload = _buildPayload(
        reportedCount: 3,
        rows: [
          (
            prefix: Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
            lastHeardSecs: 0,
            snrRaw: 0,
          ),
        ],
      );
      final parsed = MeshCoreNeighborsResponse.parse(payload);
      final text = parsed.toString();
      expect(text, contains('reported=3'));
      expect(text, contains('results=1'));
      expect(text, isNot(contains('deadbeef')));
      expect(text, isNot(contains('DEADBEEF')));
    });

    test('returned results list is unmodifiable', () {
      final payload = _buildPayload(
        reportedCount: 1,
        rows: [
          (
            prefix: Uint8List.fromList([1, 2, 3, 4]),
            lastHeardSecs: 1,
            snrRaw: 0,
          ),
        ],
      );
      final parsed = MeshCoreNeighborsResponse.parse(payload);
      expect(
        () => parsed!.results.add(
          MeshCoreNeighbor(
            pubKeyPrefix: Uint8List(4),
            lastHeard: Duration.zero,
            snrQuarter: 0,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
