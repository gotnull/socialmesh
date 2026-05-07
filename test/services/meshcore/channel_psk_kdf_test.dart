// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34d — channel PSK helper tests.
//
// Pins:
//   - randomPsk length + non-determinism (smoke)
//   - derivePskFromPassphrase determinism + ONE byte vector under the
//     locked HMAC label `socialmesh.meshcore.channel.v1`
//   - empty / whitespace-only passphrase rejection
//   - formatPskHex lowercase 32-char + length validation

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/channel_psk_kdf.dart';

void main() {
  group('randomPsk', () {
    test('returns exactly 16 bytes', () {
      expect(randomPsk().length, 16);
    });

    test(
      'is non-deterministic across calls (smoke — 8 calls all distinct)',
      () {
        // 16 bytes from `Random.secure()`; collision probability is 1/2^128
        // per pair, so 8 sequential calls colliding is practically impossible.
        // If this ever fails, treat as a regression and look for an
        // accidental seeded RNG.
        final samples = <String>{};
        for (var i = 0; i < 8; i++) {
          samples.add(formatPskHex(randomPsk()));
        }
        expect(samples.length, 8);
      },
    );

    test('does NOT return the canonical [0,1,2,...,15] sequence', () {
      // Defensive: a future refactor that switches to a non-secure RNG /
      // a debug stub seed could regress here. Pin against the canonical
      // monotonic sequence used in many test helpers across the repo so a
      // mistakenly-stubbed RNG surfaces immediately.
      final canonical = Uint8List.fromList(List.generate(16, (i) => i));
      // Run many times; at least one must differ from the canonical seed.
      var sawDistinct = false;
      for (var i = 0; i < 32; i++) {
        if (formatPskHex(randomPsk()) != formatPskHex(canonical)) {
          sawDistinct = true;
          break;
        }
      }
      expect(sawDistinct, isTrue);
    });
  });

  group('derivePskFromPassphrase', () {
    test('is deterministic for a given passphrase', () {
      final a = derivePskFromPassphrase('alpha bravo');
      final b = derivePskFromPassphrase('alpha bravo');
      expect(formatPskHex(a), formatPskHex(b));
    });

    test('"test phrase" pins to '
        '5f37102be03ffac2f2f329df52bd365d under '
        'kMeshCoreChannelKdfLabel "socialmesh.meshcore.channel.v1"', () {
      // Authoritative byte vector — recomputing this value against the
      // upstream `crypto` package confirms HMAC-SHA256(label, "test phrase")
      // truncated to the first 16 bytes. If this test ever changes value,
      // either the label or the truncation length silently moved; treat as
      // a wire-format-equivalent regression and revert.
      final psk = derivePskFromPassphrase('test phrase');
      expect(formatPskHex(psk), '5f37102be03ffac2f2f329df52bd365d');
    });

    test('different passphrases produce different PSKs', () {
      final a = derivePskFromPassphrase('alpha');
      final b = derivePskFromPassphrase('beta');
      expect(formatPskHex(a), isNot(equals(formatPskHex(b))));
    });

    test('empty passphrase throws ArgumentError', () {
      expect(() => derivePskFromPassphrase(''), throwsArgumentError);
    });

    test('whitespace-only passphrase throws ArgumentError', () {
      expect(() => derivePskFromPassphrase('   '), throwsArgumentError);
      expect(() => derivePskFromPassphrase('\t\n '), throwsArgumentError);
    });

    test('passphrase that contains internal whitespace is accepted', () {
      // "alpha bravo" is valid — only fully-blank input is rejected.
      expect(() => derivePskFromPassphrase('alpha bravo'), returnsNormally);
    });

    test('label is versioned (kMeshCoreChannelKdfLabel ends with .v1)', () {
      // Pinning the label guards against an accidental v2 bump that
      // would break every existing passphrase-derived channel.
      expect(kMeshCoreChannelKdfLabel, 'socialmesh.meshcore.channel.v1');
    });
  });

  group('formatPskHex', () {
    test('returns 32 lowercase hex characters', () {
      final psk = derivePskFromPassphrase('hello world');
      final hex = formatPskHex(psk);
      expect(hex.length, 32);
      expect(hex, hex.toLowerCase());
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(hex), isTrue);
    });

    test('throws ArgumentError when input is not exactly 16 bytes', () {
      expect(
        () => formatPskHex(Uint8List.fromList(List.filled(8, 0xAB))),
        throwsArgumentError,
      );
      expect(
        () => formatPskHex(Uint8List.fromList(List.filled(32, 0xAB))),
        throwsArgumentError,
      );
      expect(() => formatPskHex(Uint8List(0)), throwsArgumentError);
    });

    test('round-trips a known byte vector', () {
      // Tiny end-to-end check: bytes [0x00, 0x01, ..., 0x0f] format to
      // the canonical lowercase hex string.
      final bytes = Uint8List.fromList(List.generate(16, (i) => i));
      expect(formatPskHex(bytes), '000102030405060708090a0b0c0d0e0f');
    });
  });

  group('kMeshCoreChannelPskBytes', () {
    test('matches firmware AES-128 PSK width (16 bytes)', () {
      expect(kMeshCoreChannelPskBytes, 16);
    });
  });
}
