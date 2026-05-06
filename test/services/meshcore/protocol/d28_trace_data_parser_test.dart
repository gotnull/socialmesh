// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D28 Part C - parser tests for `PUSH_CODE_TRACE_DATA` (0x89).
//
// Wire format the parser must reproduce byte-for-byte (payload AFTER
// the framer strips the opcode):
//
//   [0]      reserved          u8
//   [1]      path_length       u8
//   [2]      flag              u8
//   [3..6]   tag               u32 LE
//   [7..10]  auth_code         u32 LE
//   [11..]   path_data         (path_length bytes)
//   [11+pl..] snr_array        (path_length bytes, signed int8 / 4 -> dB)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

void main() {
  group('parseTraceData - happy path', () {
    test('parses single-hop response', () {
      // tag=0x12345678, auth=0xAABBCCDD, flag=0x01, pathLen=1
      // path=[0x42], snr=[0x14] (20 quarter-units = 5.0 dB)
      final payload = Uint8List.fromList([
        0x00, // reserved
        0x01, // pathLen
        0x01, // flag
        0x78, 0x56, 0x34, 0x12, // tag LE
        0xDD, 0xCC, 0xBB, 0xAA, // auth LE
        0x42, // path[0]
        0x14, // snr[0] = 20 -> 5.0 dB
      ]);
      final result = parseTraceData(payload);
      expect(result.isSuccess, isTrue, reason: result.error);
      final v = result.value!;
      expect(v.tag, 0x12345678);
      expect(v.authCode, 0xAABBCCDD);
      expect(v.flag, 0x01);
      expect(v.hops, hasLength(1));
      expect(v.hops[0].pathByte, 0x42);
      expect(v.hops[0].snrQuarter, 20);
      expect(v.hops[0].snrDb, 5.0);
    });

    test('parses three-hop response with mixed positive and negative SNR', () {
      // pathLen=3, hops=[A,B,C], SNR=[+8/4=2dB, -8/4=-2dB, -28/4=-7dB]
      final payload = Uint8List.fromList([
        0x00, // reserved
        0x03, // pathLen
        0x00, // flag
        0x01, 0x00, 0x00, 0x00, // tag = 1
        0x00, 0x00, 0x00, 0x00, // auth = 0
        0xAA, 0xBB, 0xCC, // path
        0x08, 0xF8, 0xE4, // snr (signed int8: 8, -8, -28)
      ]);
      final result = parseTraceData(payload);
      expect(result.isSuccess, isTrue);
      final v = result.value!;
      expect(v.hops, hasLength(3));
      expect(v.hops[0].pathByte, 0xAA);
      expect(v.hops[0].snrDb, 2.0);
      expect(v.hops[1].pathByte, 0xBB);
      expect(v.hops[1].snrQuarter, -8);
      expect(v.hops[1].snrDb, -2.0);
      expect(v.hops[2].pathByte, 0xCC);
      expect(v.hops[2].snrQuarter, -28);
      expect(v.hops[2].snrDb, -7.0);
    });

    test('parses zero-hop response (firmware can send pathLen=0)', () {
      final payload = Uint8List.fromList([
        0x00, // reserved
        0x00, // pathLen
        0x00, // flag
        0xEE, 0xFF, 0xCC, 0xBB, // tag
        0x00, 0x00, 0x00, 0x00, // auth
      ]);
      final result = parseTraceData(payload);
      expect(result.isSuccess, isTrue);
      expect(result.value!.hops, isEmpty);
      expect(result.value!.tag, 0xBBCCFFEE);
    });
  });

  group('parseTraceData - rejection', () {
    test('rejects payload shorter than the 11-byte header', () {
      final payload = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
      final result = parseTraceData(payload);
      expect(result.isFailure, isTrue);
      expect(result.error, contains('too short'));
    });

    test('rejects truncated path/SNR section', () {
      // Claims 3 hops but only includes 2 path bytes + 0 snr bytes.
      final payload = Uint8List.fromList([
        0x00, 0x03, 0x00,
        0x01, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0xAA, 0xBB, // only 2 path bytes
      ]);
      final result = parseTraceData(payload);
      expect(result.isFailure, isTrue);
      expect(result.error, contains('truncated'));
    });
  });

  group('parseTraceData - SNR signed-int8 boundary', () {
    test('snr=0x80 decodes to -128 quarter-units (-32.0 dB)', () {
      final payload = Uint8List.fromList([
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x80,
      ]);
      final r = parseTraceData(payload);
      expect(r.isSuccess, isTrue);
      expect(r.value!.hops[0].snrQuarter, -128);
      expect(r.value!.hops[0].snrDb, -32.0);
    });

    test('snr=0x7F decodes to +127 quarter-units (31.75 dB)', () {
      final payload = Uint8List.fromList([
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x7F,
      ]);
      final r = parseTraceData(payload);
      expect(r.isSuccess, isTrue);
      expect(r.value!.hops[0].snrQuarter, 127);
      expect(r.value!.hops[0].snrDb, closeTo(31.75, 0.001));
    });
  });

  group('MeshCoreTraceHop / MeshCoreTraceResult', () {
    test('hop snrDb matches snrQuarter / 4.0', () {
      final hop = MeshCoreTraceHop(pathByte: 1, snrQuarter: 21);
      expect(hop.snrDb, 5.25);
    });

    test('toString does not leak full pubkey or raw snr byte', () {
      final hop = MeshCoreTraceHop(pathByte: 0x42, snrQuarter: -16);
      final s = hop.toString();
      expect(s, contains('pathByte=0x42'));
      expect(s, contains('-4.00dB'));
    });
  });
}
