// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D48-A2: `computeExpectedAckHash` byte-pin.
//
// The firmware in `MeshCore/examples/companion_radio/MyMesh.cpp`
// computes the same SHA-256 over
//   [timestamp:u32 LE][attempt & 0x03 :u8][text utf-8][sender pubkey:32 B]
// and stores the first 4 bytes (LE u32) as the `expected_ack_hash`
// in its `expected_ack_table`. The orchestrator's retry loop must
// hand the router the SAME hash so a 0x82 push routes correctly.
//
// Pinned invariants:
//   - Output is a stable u32 for a fixed (timestamp, attempt, text,
//     pubkey) tuple.
//   - Changing any one input mutates the hash.
//   - Only the bottom 2 bits of `attempt` are folded in (firmware
//     mask). attempts 0/4/8 collide; 1/5/9 collide; ...
//   - The hash is independent of whether text bytes contain
//     multi-byte UTF-8 (we go through `utf8.encode`).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/routing/meshcore_path_selector.dart';

final _ourPubKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));

void main() {
  group('computeExpectedAckHash - D48-A2', () {
    test('is deterministic for fixed inputs', () {
      final a = computeExpectedAckHash(
        timestampSeconds: 1715000000,
        attempt: 0,
        text: 'hello world',
        senderPubKey: _ourPubKey,
      );
      final b = computeExpectedAckHash(
        timestampSeconds: 1715000000,
        attempt: 0,
        text: 'hello world',
        senderPubKey: _ourPubKey,
      );
      expect(a, equals(b));
    });

    test('output fits in u32', () {
      final hash = computeExpectedAckHash(
        timestampSeconds: 1715000000,
        attempt: 0,
        text: 'x',
        senderPubKey: _ourPubKey,
      );
      expect(hash, greaterThanOrEqualTo(0));
      expect(hash, lessThanOrEqualTo(0xFFFFFFFF));
    });

    test('changing the text mutates the hash', () {
      final a = computeExpectedAckHash(
        timestampSeconds: 1715000000,
        attempt: 0,
        text: 'hello',
        senderPubKey: _ourPubKey,
      );
      final b = computeExpectedAckHash(
        timestampSeconds: 1715000000,
        attempt: 0,
        text: 'world',
        senderPubKey: _ourPubKey,
      );
      expect(a, isNot(equals(b)));
    });

    test('changing the timestamp mutates the hash', () {
      final a = computeExpectedAckHash(
        timestampSeconds: 1715000000,
        attempt: 0,
        text: 'x',
        senderPubKey: _ourPubKey,
      );
      final b = computeExpectedAckHash(
        timestampSeconds: 1715000001,
        attempt: 0,
        text: 'x',
        senderPubKey: _ourPubKey,
      );
      expect(a, isNot(equals(b)));
    });

    test('changing the sender pubkey mutates the hash', () {
      final other = Uint8List.fromList(List<int>.generate(32, (i) => i + 100));
      final a = computeExpectedAckHash(
        timestampSeconds: 1715000000,
        attempt: 0,
        text: 'x',
        senderPubKey: _ourPubKey,
      );
      final b = computeExpectedAckHash(
        timestampSeconds: 1715000000,
        attempt: 0,
        text: 'x',
        senderPubKey: other,
      );
      expect(a, isNot(equals(b)));
    });

    test('attempt 0/4/8 collide (only bottom 2 bits feed the hash)', () {
      final a0 = computeExpectedAckHash(
        timestampSeconds: 1715000000,
        attempt: 0,
        text: 'x',
        senderPubKey: _ourPubKey,
      );
      final a4 = computeExpectedAckHash(
        timestampSeconds: 1715000000,
        attempt: 4,
        text: 'x',
        senderPubKey: _ourPubKey,
      );
      final a8 = computeExpectedAckHash(
        timestampSeconds: 1715000000,
        attempt: 8,
        text: 'x',
        senderPubKey: _ourPubKey,
      );
      expect(a0, equals(a4));
      expect(a0, equals(a8));
    });

    test('attempts 0..3 produce four distinct hashes', () {
      final hashes = <int>{
        for (var i = 0; i < 4; i++)
          computeExpectedAckHash(
            timestampSeconds: 1715000000,
            attempt: i,
            text: 'x',
            senderPubKey: _ourPubKey,
          ),
      };
      expect(hashes.length, equals(4));
    });

    test('multi-byte UTF-8 text produces a stable hash', () {
      final a = computeExpectedAckHash(
        timestampSeconds: 1715000000,
        attempt: 0,
        text: 'héllo wörld emoji body',
        senderPubKey: _ourPubKey,
      );
      final b = computeExpectedAckHash(
        timestampSeconds: 1715000000,
        attempt: 0,
        text: 'héllo wörld emoji body',
        senderPubKey: _ourPubKey,
      );
      expect(a, equals(b));
    });
  });
}
