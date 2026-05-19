// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Phase 3 Slice A — pins the pubkey-to-int derivation that produces
// the stable per-contact `from` value handed to the automation
// engine + IFTTT service for MeshCore inbound messages.
//
// The dedupe key the automation engine builds for `messageReceived`
// is `messageReceived_node{from}`, so consistency-across-messages
// matters for the user-visible "fires once per peer per 60s"
// throttle behaviour. Channel frames (no firmware-supplied sender
// identity) collapse to 0 - which is intentional and matches the
// limitation surfaced in the OS notification path.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/providers/meshcore_message_providers.dart';

void main() {
  group('meshCoreSenderIdFromKey', () {
    test('null key collapses to 0 (channel-message path)', () {
      expect(meshCoreSenderIdFromKey(null), 0);
    });

    test('empty key collapses to 0', () {
      expect(meshCoreSenderIdFromKey(Uint8List(0)), 0);
    });

    test('keys shorter than 4 bytes collapse to 0', () {
      expect(meshCoreSenderIdFromKey(Uint8List.fromList([0xAB, 0xCD])), 0);
      expect(
        meshCoreSenderIdFromKey(Uint8List.fromList([0xAB, 0xCD, 0xEF])),
        0,
      );
    });

    test('first 4 bytes decoded as big-endian uint32', () {
      // 0x01_02_03_04 = 16909060
      expect(
        meshCoreSenderIdFromKey(Uint8List.fromList([0x01, 0x02, 0x03, 0x04])),
        16909060,
      );
    });

    test('trailing bytes are ignored (32-byte pubkey only uses first 4)', () {
      final shortKey = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
      final full = Uint8List(32);
      full[0] = 0xDE;
      full[1] = 0xAD;
      full[2] = 0xBE;
      full[3] = 0xEF;
      // Trailing bytes vary - shouldn't affect the result.
      for (var i = 4; i < 32; i++) {
        full[i] = i;
      }
      expect(meshCoreSenderIdFromKey(shortKey), meshCoreSenderIdFromKey(full));
    });

    test('stable across calls (same key produces same id)', () {
      final key = Uint8List.fromList(List.generate(32, (i) => i * 3));
      final first = meshCoreSenderIdFromKey(key);
      final second = meshCoreSenderIdFromKey(key);
      expect(first, second);
    });

    test('different keys produce different ids (collision sanity)', () {
      final keyA = Uint8List.fromList([0x11, 0x22, 0x33, 0x44]);
      final keyB = Uint8List.fromList([0x11, 0x22, 0x33, 0x45]);
      expect(
        meshCoreSenderIdFromKey(keyA),
        isNot(meshCoreSenderIdFromKey(keyB)),
      );
    });
  });
}
