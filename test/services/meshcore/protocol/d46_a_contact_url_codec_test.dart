// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D46-A: `MeshCoreContactUrl` codec + `parseLegacyContactCode` pins.
//
// Wire-symmetric round trip:
//   firmware `CMD_EXPORT_CONTACT 0x11` returns 135..147-byte canonical
//   contact frame → `encode` → `meshcore://<hex>` → `decode` → same
//   bytes byte-for-byte → `CMD_IMPORT_CONTACT 0x12`.
//
// Pinned invariants:
//   - encode 135-byte frame returns `meshcore://<270-char hex>`.
//   - encode 147-byte frame returns `meshcore://<294-char hex>`.
//   - encode out-of-range (134, 148, 0) throws ArgumentError.
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
    test('135-byte frame encodes to meshcore://<270-char hex>', () {
      final url = MeshCoreContactUrl.encode(_frame(135));
      expect(url.startsWith('meshcore://'), isTrue);
      final hex = url.substring(MeshCoreContactUrl.scheme.length);
      expect(hex.length, 270);
    });

    test('147-byte frame encodes to meshcore://<294-char hex>', () {
      final url = MeshCoreContactUrl.encode(_frame(147));
      expect(url.substring(MeshCoreContactUrl.scheme.length).length, 294);
    });

    test('134-byte frame throws ArgumentError', () {
      expect(() => MeshCoreContactUrl.encode(_frame(134)), throwsArgumentError);
    });

    test('148-byte frame throws ArgumentError', () {
      expect(() => MeshCoreContactUrl.encode(_frame(148)), throwsArgumentError);
    });

    test('empty frame throws ArgumentError', () {
      expect(
        () => MeshCoreContactUrl.encode(Uint8List(0)),
        throwsArgumentError,
      );
    });
  });

  group('MeshCoreContactUrl.decode - D46-A', () {
    test('round-trips a 135-byte frame byte-for-byte', () {
      final frame = _frame(135, seed: 7);
      final url = MeshCoreContactUrl.encode(frame);
      final out = MeshCoreContactUrl.decode(url);
      expect(out, isNotNull);
      expect(out, equals(frame));
    });

    test('round-trips a 147-byte frame byte-for-byte', () {
      final frame = _frame(147, seed: 13);
      final out = MeshCoreContactUrl.decode(MeshCoreContactUrl.encode(frame));
      expect(out, equals(frame));
    });

    test('decode tolerates leading and trailing whitespace', () {
      final frame = _frame(135);
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
      // 271 hex chars = 135.5 bytes — invalid.
      final oddHex = '0' * 271;
      expect(MeshCoreContactUrl.decode('meshcore://$oddHex'), isNull);
    });

    test('non-hex chars return null', () {
      // Length is correct (270 chars) but contains a non-hex char.
      final badHex = 'gg${'00' * 134}';
      expect(MeshCoreContactUrl.decode('meshcore://$badHex'), isNull);
    });

    test('too-short hex (< 135 bytes) returns null', () {
      // 268 chars = 134 bytes — under min.
      final shortHex = '00' * 134;
      expect(MeshCoreContactUrl.decode('meshcore://$shortHex'), isNull);
    });

    test('too-long hex (> 147 bytes) returns null', () {
      // 296 chars = 148 bytes — over max.
      final longHex = '00' * 148;
      expect(MeshCoreContactUrl.decode('meshcore://$longHex'), isNull);
    });

    test('legacy pubkey-only QR (64-char hex) returns null', () {
      // `meshcore://<32-byte hex>` looks superficially valid but is
      // shorter than the 135-byte canonical frame. Must be rejected
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
