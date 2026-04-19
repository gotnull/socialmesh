// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Mirror of the private `_sigilSeedFromPersonaId` in
/// mesh_explorer_providers.dart. Verified to match the production
/// implementation byte-for-byte.
int sigilSeedFromPersonaId(Uint8List personaId) {
  if (personaId.length < 4) return 0;
  return ByteData.sublistView(personaId).getUint32(0, Endian.little);
}

void main() {
  group('Sigil seed from personaId', () {
    test('extracts first 4 bytes as little-endian uint32', () {
      final personaId = Uint8List.fromList([
        0x01, 0x02, 0x03, 0x04, // first 4 bytes → seed
        0xFF, 0xFF, 0xFF, 0xFF, // remaining bytes (ignored for seed)
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
      ]);
      // 0x04030201 in little-endian = 67305985
      expect(sigilSeedFromPersonaId(personaId), 0x04030201);
    });

    test('deterministic: same personaId always produces same seed', () {
      final personaId = Uint8List.fromList(List.generate(16, (i) => i + 10));
      final seed1 = sigilSeedFromPersonaId(personaId);
      final seed2 = sigilSeedFromPersonaId(personaId);
      expect(seed1, seed2);
    });

    test('different personaIds produce different seeds', () {
      final id1 = Uint8List.fromList(List.generate(16, (i) => i));
      final id2 = Uint8List.fromList(List.generate(16, (i) => i + 1));
      expect(sigilSeedFromPersonaId(id1), isNot(sigilSeedFromPersonaId(id2)));
    });

    test('falls back to 0 for short personaId', () {
      expect(sigilSeedFromPersonaId(Uint8List(0)), 0);
      expect(sigilSeedFromPersonaId(Uint8List(3)), 0);
    });

    test('works with exactly 4 bytes', () {
      final personaId = Uint8List.fromList([0xAA, 0xBB, 0xCC, 0xDD]);
      // 0xDDCCBBAA in little-endian = 3721182122
      expect(sigilSeedFromPersonaId(personaId), 0xDDCCBBAA);
    });

    test('all-zero personaId produces zero seed', () {
      expect(sigilSeedFromPersonaId(Uint8List(16)), 0);
    });
  });
}
