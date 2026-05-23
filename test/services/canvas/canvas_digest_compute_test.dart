// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tests for [computeCanvasDigests].
//
// Spec: docs/canvas/CANVAS_V0_1.md §6.3 + CANVAS_SYNC_V0_1.md §2.1.
//
// Pinned invariants:
//   - empty canvas → well-defined non-zero global digest (BLAKE2s-128
//     of empty input).
//   - empty tile → its 8-byte slot matches the BLAKE2s-128(∅)[0:8].
//   - same cells in different orders → identical digests (canonical
//     sort applied internally).
//   - same cells on two different inputs → identical digests
//     (deterministic).
//   - a single-cell change flips global AND the affected tile's
//     digest; the other 15 tile slots stay byte-identical.
//   - tile partitioning matches `canvasTileIndexForCell`.

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/canvas/canvas_constants.dart';
import 'package:socialmesh/services/canvas/canvas_digest_compute.dart';
import 'package:socialmesh/services/canvas/canvas_models.dart';

void main() {
  group('computeCanvasDigests', () {
    test(
      'empty canvas returns BLAKE2s-128(∅) global + empty-tile slots',
      () async {
        final set = await computeCanvasDigests(const <CanvasCell>[]);
        expect(set.cellCount, 0);
        expect(set.globalDigest.length, CanvasDigestSizes.globalBytes);
        expect(
          set.tileDigests.length,
          CanvasDigestSizes.tilesConcatenatedBytes,
        );

        // Reference: BLAKE2s-128 of empty input.
        final emptyHash = await Blake2s(
          hashLengthInBytes: CanvasDigestSizes.globalBytes,
        ).hash(const <int>[]);
        expect(set.globalDigest, equals(emptyHash.bytes));

        // Every tile slot must equal first 8 B of BLAKE2s-128(∅).
        for (var t = 0; t < CanvasGeometry.tileCount; t++) {
          final offset = t * CanvasDigestSizes.tileBytes;
          final slot = set.tileDigests.sublist(
            offset,
            offset + CanvasDigestSizes.tileBytes,
          );
          expect(slot, equals(emptyHash.bytes.take(8).toList()));
        }

        // Sanity: digests must not be all zeros.
        expect(set.globalDigest.any((b) => b != 0), isTrue);
      },
    );

    test('single cell produces well-defined digests; correct tile slot '
        'differs from empty, other 15 stay at empty-digest', () async {
      const cell = CanvasCell(
        canvasLocalId: 1,
        x: 35,
        y: 12,
        color: 7,
        lastTs: 1700000000,
        lastAuthor: 0xAABBCCDD,
        lastSeq: 0x42,
      );
      final emptySet = await computeCanvasDigests(const <CanvasCell>[]);
      final set = await computeCanvasDigests(const <CanvasCell>[cell]);

      expect(set.cellCount, 1);
      expect(set.globalDigest, isNot(equals(emptySet.globalDigest)));

      // Cell (35, 12) → tile (1, 0) → tile_idx = 0 * 4 + 1 = 1.
      final affectedTile = canvasTileIndexForCell(35, 12);
      expect(affectedTile, 1);

      for (var t = 0; t < CanvasGeometry.tileCount; t++) {
        final offset = t * CanvasDigestSizes.tileBytes;
        final slot = set.tileDigests.sublist(
          offset,
          offset + CanvasDigestSizes.tileBytes,
        );
        final emptySlot = emptySet.tileDigests.sublist(
          offset,
          offset + CanvasDigestSizes.tileBytes,
        );
        if (t == affectedTile) {
          expect(
            slot,
            isNot(equals(emptySlot)),
            reason: 'affected tile slot must differ from empty',
          );
        } else {
          expect(
            slot,
            equals(emptySlot),
            reason:
                'tile $t was not touched; its 8-byte slot must equal the '
                'empty-tile digest',
          );
        }
      }
    });

    test(
      'input order does not affect output (canonical sort by y,x)',
      () async {
        final cells = <CanvasCell>[
          const CanvasCell(
            canvasLocalId: 1,
            x: 10,
            y: 5,
            color: 2,
            lastTs: 100,
            lastAuthor: 1,
            lastSeq: 0,
          ),
          const CanvasCell(
            canvasLocalId: 1,
            x: 3,
            y: 2,
            color: 4,
            lastTs: 200,
            lastAuthor: 2,
            lastSeq: 1,
          ),
          const CanvasCell(
            canvasLocalId: 1,
            x: 50,
            y: 50,
            color: 6,
            lastTs: 300,
            lastAuthor: 3,
            lastSeq: 2,
          ),
        ];
        final reversed = cells.reversed.toList();
        final a = await computeCanvasDigests(cells);
        final b = await computeCanvasDigests(reversed);
        expect(a.globalDigest, equals(b.globalDigest));
        expect(a.tileDigests, equals(b.tileDigests));
      },
    );

    test('flipping a single cell\'s color changes ONLY that cell\'s tile '
        'plus the global digest', () async {
      const baseCell = CanvasCell(
        canvasLocalId: 1,
        x: 70,
        y: 70,
        color: 1,
        lastTs: 1000,
        lastAuthor: 1,
        lastSeq: 0,
      );
      const flipped = CanvasCell(
        canvasLocalId: 1,
        x: 70,
        y: 70,
        color: 5,
        lastTs: 1000,
        lastAuthor: 1,
        lastSeq: 0,
      );
      // Some pre-existing background cells in other tiles to ensure
      // those tile digests are non-empty.
      final cellsBefore = <CanvasCell>[
        baseCell,
        const CanvasCell(
          canvasLocalId: 1,
          x: 5,
          y: 5,
          color: 2,
          lastTs: 1,
          lastAuthor: 1,
          lastSeq: 0,
        ),
      ];
      final cellsAfter = <CanvasCell>[
        flipped,
        const CanvasCell(
          canvasLocalId: 1,
          x: 5,
          y: 5,
          color: 2,
          lastTs: 1,
          lastAuthor: 1,
          lastSeq: 0,
        ),
      ];
      final a = await computeCanvasDigests(cellsBefore);
      final b = await computeCanvasDigests(cellsAfter);

      expect(a.globalDigest, isNot(equals(b.globalDigest)));

      // Cell (70, 70) → tile (70/32, 70/32) = (2, 2) → idx = 2*4+2 = 10.
      final affectedTile = canvasTileIndexForCell(70, 70);
      expect(affectedTile, 10);

      for (var t = 0; t < CanvasGeometry.tileCount; t++) {
        final offset = t * CanvasDigestSizes.tileBytes;
        final aSlot = a.tileDigests.sublist(
          offset,
          offset + CanvasDigestSizes.tileBytes,
        );
        final bSlot = b.tileDigests.sublist(
          offset,
          offset + CanvasDigestSizes.tileBytes,
        );
        if (t == affectedTile) {
          expect(aSlot, isNot(equals(bSlot)));
        } else {
          expect(aSlot, equals(bSlot), reason: 'tile $t was not touched');
        }
      }
    });

    test('two devices with the same painted cells produce identical digests '
        '(determinism contract)', () async {
      final cells = <CanvasCell>[
        for (var i = 0; i < 50; i++)
          CanvasCell(
            canvasLocalId: 1,
            x: i * 2,
            y: i,
            color: i % 8,
            lastTs: 1000 + i,
            lastAuthor: 0xCAFE0000 + i,
            lastSeq: i & 0xff,
          ),
      ];
      final deviceA = await computeCanvasDigests(cells);
      final deviceB = await computeCanvasDigests(cells.reversed.toList());
      expect(deviceA.globalDigest, equals(deviceB.globalDigest));
      expect(deviceA.tileDigests, equals(deviceB.tileDigests));
      expect(deviceA.cellCount, deviceB.cellCount);
    });

    test(
      'cells outside canvas bounds are silently dropped (defensive)',
      () async {
        final cells = <CanvasCell>[
          const CanvasCell(
            canvasLocalId: 1,
            x: 200,
            y: 5,
            color: 1,
            lastTs: 1,
            lastAuthor: 1,
            lastSeq: 0,
          ),
          const CanvasCell(
            canvasLocalId: 1,
            x: 5,
            y: 5,
            color: 1,
            lastTs: 1,
            lastAuthor: 1,
            lastSeq: 0,
          ),
        ];
        final set = await computeCanvasDigests(cells);
        expect(set.cellCount, 1);
      },
    );
  });
}
