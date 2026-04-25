// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_fragment.dart';

void main() {
  const parser = ReticulumFragmentParser();

  group('ReticulumFragmentParser — header decode', () {
    test('parses index + positive position + body', () {
      final payload = Uint8List.fromList([0x05, 0x02, 0xAA, 0xBB, 0xCC]);
      final h = parser.parse(payload);
      expect(h.index, 5);
      expect(h.position, 2);
      expect(h.isLast, isFalse);
      expect(h.fragmentNumber, 2);
      expect(h.body, [0xAA, 0xBB, 0xCC]);
    });

    test('decodes negative position via int8 sign extension', () {
      // 0xFF as int8 = -1
      final payload = Uint8List.fromList([0x00, 0xFF, 0xDE, 0xAD]);
      final h = parser.parse(payload);
      expect(h.index, 0);
      expect(h.position, -1);
      expect(h.isLast, isTrue);
      expect(h.fragmentNumber, 1);
    });

    test('-3 (last fragment of 3-fragment frame) decodes correctly', () {
      // 0xFD as int8 = -3
      final payload = Uint8List.fromList([0x07, 0xFD, 0x42]);
      final h = parser.parse(payload);
      expect(h.position, -3);
      expect(h.isLast, isTrue);
      expect(h.fragmentNumber, 3);
    });

    test('rejects too-short payload', () {
      expect(
        () => parser.parse(Uint8List.fromList([0x00])),
        throwsA(
          isA<ReticulumFragmentDecodeError>().having(
            (e) => e.reason,
            'reason',
            startsWith('short_payload'),
          ),
        ),
      );
    });

    test('rejects zero position (not a valid 1-indexed wire value)', () {
      final payload = Uint8List.fromList([0x05, 0x00, 0xAA]);
      expect(
        () => parser.parse(payload),
        throwsA(
          isA<ReticulumFragmentDecodeError>().having(
            (e) => e.reason,
            'reason',
            'zero_position',
          ),
        ),
      );
    });

    test('empty body is allowed when payload is exactly 2 bytes', () {
      final h = parser.parse(Uint8List.fromList([0x09, 0xFF]));
      expect(h.index, 9);
      expect(h.position, -1);
      expect(h.body, isEmpty);
    });
  });

  group('Captured-byte vectors from real RF (2026-04-25)', () {
    // Pinned from the 2026-04-25T08-22-52.909194Z captures. These are
    // the actual position bytes observed from `landandair/RNS_Over_Meshtastic`
    // running standalone — promote-to-v1.0 evidence.
    test('single-fragment announce: index=0, position=-1', () {
      final payload = Uint8List.fromList([
        0x00, 0xFF, // header: index=0, position=-1
        0x51, 0x00, 0x7F, 0x1F, 0xF3, 0x80, 0xA7, 0x70, // body prefix
      ]);
      final h = parser.parse(payload);
      expect(h.index, 0);
      expect(h.position, -1);
      expect(h.isLast, isTrue);
      expect(h.body.length, 8);
    });

    test('multi-fragment frame: position=1 (non-last)', () {
      final payload = Uint8List.fromList([0x02, 0x01, 0x00, 0x11, 0x22]);
      final h = parser.parse(payload);
      expect(h.position, 1);
      expect(h.isLast, isFalse);
      expect(h.fragmentNumber, 1);
    });

    test('multi-fragment frame: position=-3 (last of N=3)', () {
      final payload = Uint8List.fromList([0x01, 0xFD, 0xAB, 0xCD]);
      final h = parser.parse(payload);
      expect(h.position, -3);
      expect(h.isLast, isTrue);
      expect(h.fragmentNumber, 3);
    });
  });
}
