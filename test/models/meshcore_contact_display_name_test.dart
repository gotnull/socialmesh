// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D23 — `MeshCoreContact.displayName` fallback regression pins.
//
// The chat header and Contacts list previously rendered the literal
// localized "Unknown" string for any firmware contact entry whose
// `name` field was empty (auto-added contacts from inbound mesh
// adverts that did not carry a friendly name look broken otherwise).
// The new `displayName` getter resolves to a redacted public-key
// fingerprint in that case, matching the log channel's pubkey
// redaction shape, and only falls through to `''` (caller's localized
// placeholder) when the public key itself is too short to fingerprint.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/meshcore_contact.dart';

MeshCoreContact _contact({required String name, required Uint8List publicKey}) {
  return MeshCoreContact(
    publicKey: publicKey,
    name: name,
    type: MeshCoreAdvType.chat,
    pathLength: 0,
    path: Uint8List(0),
    lastSeen: DateTime(2026, 5, 6),
  );
}

void main() {
  group('MeshCoreContact.displayName (D23)', () {
    test('non-empty name is preserved verbatim', () {
      final c = _contact(
        name: 'TerryDev',
        publicKey: Uint8List.fromList(List.generate(32, (i) => 0x79 + (i % 8))),
      );
      expect(c.displayName, equals('TerryDev'));
    });

    test('empty name falls back to redacted public-key fingerprint', () {
      // Realistic Radio-A pubkey shape: 32 bytes. Fingerprint must
      // mirror `shortPubKeyHex` (`<8hex>…<8hex>`) so the UI fallback
      // and the structured log fingerprint are the same shape — one
      // format users learn once.
      final pubKey = Uint8List.fromList([
        0x79, 0x42, 0x6d, 0x8d, // head
        ...List.filled(24, 0xaa),
        0x08, 0x31, 0x78, 0x2b, // tail
      ]);
      final c = _contact(name: '', publicKey: pubKey);
      expect(c.displayName, equals('<79426d8d…0831782b>'));
    });

    test(
      'whitespace-only names are treated as non-empty (firmware-only contract)',
      () {
        // Firmware never emits whitespace-only names, so the contract
        // is "byte-empty fallback only". Pin so a future "trim then
        // check empty" change is intentional.
        final c = _contact(
          name: ' ',
          publicKey: Uint8List.fromList(List.generate(32, (i) => i)),
        );
        expect(c.displayName, equals(' '));
      },
    );

    test('empty name + empty public key returns empty string', () {
      // Caller is responsible for falling through to the localized
      // "Unknown" placeholder in this rare case (firmware contract
      // says one of the two will always be present, but defensive).
      final c = _contact(name: '', publicKey: Uint8List(0));
      expect(c.displayName, equals(''));
    });

    test('empty name + short (sub-8B) public key returns empty string', () {
      // Defensive: a 4-byte pubkey would produce only 8 hex chars,
      // not enough for the `<8…8>` shape. Bail out instead of
      // emitting an asymmetric fingerprint.
      final c = _contact(
        name: '',
        publicKey: Uint8List.fromList([0x12, 0x34, 0x56, 0x78]),
      );
      expect(c.displayName, equals(''));
    });

    test('fallback never exposes the full 64-char public-key hex', () {
      // Anti-leak guard: even with a maximally distinctive key,
      // displayName must NEVER contain the contiguous 64-char hex
      // string. The `<8…8>` shape is the contract; mid-bytes are
      // dropped.
      final pubKey = Uint8List.fromList(List.generate(32, (i) => 0xa0 + i));
      final fullHex = pubKey
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final c = _contact(name: '', publicKey: pubKey);

      expect(c.displayName, contains('…'));
      expect(c.displayName.contains(fullHex), isFalse);
      // Spot-check: the head and tail 8 chars are present (and only
      // those — no contiguous 16+ hex run).
      expect(c.displayName, contains('a0a1a2a3'));
      expect(c.displayName, contains('bcbdbebf'));
      expect(c.displayName.length, equals('<a0a1a2a3…bcbdbebf>'.length));
    });

    test(
      'named contact with valid pubkey still uses name (not fingerprint)',
      () {
        // Anti-regression: ensure adding the fingerprint fallback does
        // not silently override a legitimate name.
        final pubKey = Uint8List.fromList(List.generate(32, (i) => i));
        final c = _contact(name: 'WisMeshCore', publicKey: pubKey);
        expect(c.displayName, equals('WisMeshCore'));
        expect(c.displayName, isNot(contains('…')));
      },
    );
  });
}
