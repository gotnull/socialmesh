// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Wire-contract pin for [deriveCanvasIdFromChannel].
//
// CANVAS_V0_1.md §3 declares:
//
//   canvas_id = first 8 bytes (little-endian u64) of
//               SHA-256(channel_psk_bytes_or_empty || canvas_name_utf8)
//
// Both sides of a paint exchange compute this independently — they
// never negotiate. So the derivation must be:
//   1) deterministic for fixed (psk, name) input,
//   2) byte-exact against the spec test vector (well-known SHA-256 of
//      the concatenated input),
//   3) different for different (psk, name) inputs,
//   4) defined on empty psk (default-keyed channels).
//
// This file is the only floor between a future refactor of the
// derivation and "two devices on the same channel can't agree on a
// canvas id."
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/canvas/canvas_constants.dart';

int _spec(Iterable<int> psk, String name) {
  // Reference implementation re-derived from the spec text so the
  // test does not just call the function under test. This is what
  // makes the test a real pin — they must agree byte for byte.
  final input = <int>[...psk, ...utf8.encode(name)];
  final hash = sha256.convert(input).bytes;
  var id = 0;
  for (var i = 0; i < 8; i++) {
    id |= (hash[i] & 0xff) << (i * 8);
  }
  return id;
}

void main() {
  group('deriveCanvasIdFromChannel — CANVAS_V0_1.md §3', () {
    test('is deterministic for fixed (psk, name)', () {
      const psk = <int>[1, 2, 3, 4, 5];
      const name = 'Primary';
      final a = deriveCanvasIdFromChannel(channelPsk: psk, canvasName: name);
      final b = deriveCanvasIdFromChannel(channelPsk: psk, canvasName: name);
      expect(a, b);
    });

    test('matches the spec-text reference implementation byte-for-byte', () {
      const psk = <int>[0xAA, 0xBB, 0xCC, 0xDD];
      const name = 'LongFast';
      expect(
        deriveCanvasIdFromChannel(channelPsk: psk, canvasName: name),
        _spec(psk, name),
      );
    });

    test('defined on empty psk (default-keyed channels)', () {
      expect(
        deriveCanvasIdFromChannel(
          channelPsk: const <int>[],
          canvasName: 'Primary',
        ),
        _spec(const <int>[], 'Primary'),
      );
    });

    test('differs for different names with the same psk', () {
      const psk = <int>[1, 2, 3];
      expect(
        deriveCanvasIdFromChannel(channelPsk: psk, canvasName: 'Primary'),
        isNot(
          deriveCanvasIdFromChannel(channelPsk: psk, canvasName: 'LongFast'),
        ),
      );
    });

    test('differs for different psks with the same name', () {
      const name = 'Primary';
      expect(
        deriveCanvasIdFromChannel(channelPsk: const [1], canvasName: name),
        isNot(
          deriveCanvasIdFromChannel(channelPsk: const [2], canvasName: name),
        ),
      );
    });
  });
}
