// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D46-A: `MeshCoreContactUrl` codec + `parseLegacyContactCode` pins.
//
// Wire-symmetric round trip:
//   firmware `CMD_EXPORT_CONTACT 0x11` returns a 98..171-byte advert packet
//   contact frame → `encode` → `meshcore://<hex>` → `decode` → same
//   bytes byte-for-byte → `CMD_IMPORT_CONTACT 0x12`.
//
// Pinned invariants:
//   - encode 98-byte packet returns `meshcore://<196-char hex>`.
//   - encode 171-byte packet returns `meshcore://<342-char hex>`.
//   - encode out-of-range (97, 172, 0) throws ArgumentError.
//   - decode round-trips byte-for-byte.
//   - decode malformed inputs return null cleanly:
//       wrong scheme, odd-length hex, non-hex chars, empty hex,
//       too-short or too-long byte count.
//   - parseLegacyContactCode parses a valid `<64-hex>:<name>` stub.
//   - parseLegacyContactCode rejects: empty input, missing colon,
//     wrong-length hex, non-hex chars, a leading `meshcore://`
//     (caller should route through MeshCoreContactUrl.decode).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_contact_url.dart';

Uint8List _frame(int length, {int seed = 0}) {
  return Uint8List.fromList(List.generate(length, (i) => (seed + i) & 0xFF));
}

void main() {
  group('MeshCoreContactUrl.encode - D46-A', () {
    test('98-byte packet encodes to meshcore://<196-char hex>', () {
      final url = MeshCoreContactUrl.encode(_frame(98));
      expect(url.startsWith('meshcore://'), isTrue);
      final hex = url.substring(MeshCoreContactUrl.scheme.length);
      expect(hex.length, 196);
    });

    test('171-byte packet encodes to meshcore://<342-char hex>', () {
      final url = MeshCoreContactUrl.encode(_frame(171));
      expect(url.substring(MeshCoreContactUrl.scheme.length).length, 342);
    });

    test('97-byte packet throws ArgumentError', () {
      expect(() => MeshCoreContactUrl.encode(_frame(97)), throwsArgumentError);
    });

    test('172-byte packet throws ArgumentError', () {
      expect(() => MeshCoreContactUrl.encode(_frame(172)), throwsArgumentError);
    });

    test('empty frame throws ArgumentError', () {
      expect(
        () => MeshCoreContactUrl.encode(Uint8List(0)),
        throwsArgumentError,
      );
    });
  });

  group('MeshCoreContactUrl.decode - D46-A', () {
    test('round-trips a 98-byte packet byte-for-byte', () {
      final frame = _frame(98, seed: 7);
      final url = MeshCoreContactUrl.encode(frame);
      final out = MeshCoreContactUrl.decode(url);
      expect(out, isNotNull);
      expect(out, equals(frame));
    });

    test('round-trips a 171-byte packet byte-for-byte', () {
      final frame = _frame(171, seed: 13);
      final out = MeshCoreContactUrl.decode(MeshCoreContactUrl.encode(frame));
      expect(out, equals(frame));
    });

    test('decode tolerates leading and trailing whitespace', () {
      final frame = _frame(98);
      final url = '  ${MeshCoreContactUrl.encode(frame)}  ';
      expect(MeshCoreContactUrl.decode(url), equals(frame));
    });

    test('wrong scheme returns null', () {
      expect(MeshCoreContactUrl.decode('http://example.com'), isNull);
      expect(MeshCoreContactUrl.decode('socialmesh://abcdef'), isNull);
      // Close-but-not-equal: missing trailing slashes.
      expect(MeshCoreContactUrl.decode('meshcore:abcdef'), isNull);
    });

    test('empty hex after scheme returns null', () {
      expect(MeshCoreContactUrl.decode('meshcore://'), isNull);
    });

    test('odd-length hex returns null', () {
      // 271 hex chars = 135.5 bytes - invalid.
      final oddHex = '0' * 271;
      expect(MeshCoreContactUrl.decode('meshcore://$oddHex'), isNull);
    });

    test('non-hex chars return null', () {
      // Even length but contains a non-hex char.
      final badHex = 'gg${'00' * 134}';
      expect(MeshCoreContactUrl.decode('meshcore://$badHex'), isNull);
    });

    test('too-short hex (< 98 bytes) returns null', () {
      final shortHex = '00' * 97;
      expect(MeshCoreContactUrl.decode('meshcore://$shortHex'), isNull);
    });

    test('too-long hex (> 171 bytes) returns null', () {
      final longHex = '00' * 172;
      expect(MeshCoreContactUrl.decode('meshcore://$longHex'), isNull);
    });

    test('legacy pubkey-only QR (64-char hex) returns null', () {
      // `meshcore://<32-byte hex>` looks superficially valid but is
      // shorter than an advert packet. Must be rejected
      // so the caller can route through parseLegacyContactCode or
      // the older `meshcore://contact/<base64>` paths.
      final pubKeyOnly = '00' * 32;
      expect(MeshCoreContactUrl.decode('meshcore://$pubKeyOnly'), isNull);
    });
  });

  group('parseLegacyContactCode - D46-A', () {
    test('parses `<64-char hex>:<name>` into a flood-path stub', () {
      final pkHex = List.generate(64, (i) => (i % 16).toRadixString(16)).join();
      final c = parseLegacyContactCode('$pkHex:Alice');
      expect(c, isNotNull);
      expect(c!.name, 'Alice');
      expect(c.pathLength, -1); // flood
      expect(c.publicKey.length, 32);
    });

    test('name may contain extra colons (joined verbatim)', () {
      final pkHex = '0' * 64;
      final c = parseLegacyContactCode('$pkHex:Bob:the:third');
      expect(c, isNotNull);
      expect(c!.name, 'Bob:the:third');
    });

    test('empty input returns null', () {
      expect(parseLegacyContactCode(''), isNull);
      expect(parseLegacyContactCode('   '), isNull);
    });

    test('missing colon returns null', () {
      expect(parseLegacyContactCode('0' * 64), isNull);
    });

    test('wrong-length hex returns null', () {
      expect(parseLegacyContactCode('aabb:Alice'), isNull);
      expect(parseLegacyContactCode('${'0' * 63}:Alice'), isNull);
      expect(parseLegacyContactCode('${'0' * 65}:Alice'), isNull);
    });

    test('non-hex chars in pubkey position return null', () {
      expect(parseLegacyContactCode('${'g' * 64}:Alice'), isNull);
    });

    test('meshcore:// prefix routes the caller through the modern decoder', () {
      // A leading `meshcore://` is the modern scheme; this helper
      // must not silently parse it and produce a misleading stub.
      expect(parseLegacyContactCode('meshcore://${'00' * 135}'), isNull);
    });
  });
}
