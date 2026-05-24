// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/canvas/canvas_codec.dart';
import 'package:socialmesh/services/canvas/canvas_constants.dart';

/// Reference: the 8-byte u64 canvas_id at offset 4 of every payload,
/// little-endian. This helper pins the exact byte sequence test
/// vectors expect.
List<int> _u64LeBytes(int v) {
  final out = List<int>.filled(8, 0);
  var rem = v;
  for (var i = 0; i < 8; i++) {
    out[i] = rem & 0xFF;
    rem >>>= 8;
  }
  return out;
}

List<int> _u32LeBytes(int v) => [
  v & 0xFF,
  (v >> 8) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 24) & 0xFF,
];

void main() {
  group('CanvasCodec.sniffAction', () {
    test('returns null on short buffer', () {
      expect(CanvasCodec.sniffAction(Uint8List(0)), isNull);
      expect(CanvasCodec.sniffAction(Uint8List(11)), isNull);
    });

    test('returns null on wrong magic', () {
      final buf = Uint8List(12)
        ..[0] = 0xAB
        ..[1] = 0x01
        ..[2] = 0x01;
      expect(CanvasCodec.sniffAction(buf), isNull);
    });

    test('returns null on unknown op_type', () {
      final buf = Uint8List(12)
        ..[0] = 0xCA
        ..[1] = 0x01
        ..[2] = 0xFF;
      expect(CanvasCodec.sniffAction(buf), isNull);
    });

    test('returns the right action for every known op_type', () {
      for (final action in CanvasAction.values) {
        final buf = Uint8List(12)
          ..[0] = CanvasWireFormat.magic
          ..[1] = CanvasWireFormat.version
          ..[2] = action.opTypeByte;
        expect(CanvasCodec.sniffAction(buf), action);
      }
    });
  });

  group('paint (action 0x0001)', () {
    test('byte-exact vector', () {
      const canvasId = 0x1122334455667788;
      const op = CanvasPaintOp(
        canvasId: canvasId,
        x: 10,
        y: 20,
        color: 5,
        authorId: 0xAABBCCDD,
        opTs: 0x11223344,
        opSeq: 9,
      );
      final encoded = CanvasCodec.encodePaint(op);
      expect(encoded, isNotNull);
      expect(encoded!.length, 24);

      final expected = <int>[
        0xCA, 0x01, 0x01, 0x00, // magic, version, op_type, flags
        ..._u64LeBytes(canvasId), //               canvas_id 4..11
        10, 20, 5, //                              x, y, color
        0xDD, 0xCC, 0xBB, 0xAA, //                 author_id u32 LE
        0x44, 0x33, 0x22, 0x11, //                 op_ts u32 LE
        9, //                                      op_seq
      ];
      expect(encoded, equals(Uint8List.fromList(expected)));
    });

    test('round-trip', () {
      const op = CanvasPaintOp(
        canvasId: 0xDEADBEEFCAFEBABE,
        // Max valid x on v0.1 64×64 grid is CanvasLimits.cellCoordMax = 63.
        x: 63,
        y: 0,
        color: 63,
        authorId: 1,
        opTs: 1_000_000,
        opSeq: 255,
      );
      final encoded = CanvasCodec.encodePaint(op)!;
      final decoded = CanvasCodec.decodePaint(encoded)!;
      expect(decoded.canvasId, op.canvasId);
      expect(decoded.x, op.x);
      expect(decoded.y, op.y);
      expect(decoded.color, op.color);
      expect(decoded.authorId, op.authorId);
      expect(decoded.opTs, op.opTs);
      expect(decoded.opSeq, op.opSeq);
      expect(decoded.anonymousAuthor, isFalse);
    });

    test('anonymous_author flag round-trips with author_id=0', () {
      const op = CanvasPaintOp(
        canvasId: 0x1,
        x: 1,
        y: 1,
        color: 1,
        authorId: 0,
        opTs: 1,
        opSeq: 0,
        anonymousAuthor: true,
      );
      final decoded = CanvasCodec.decodePaint(CanvasCodec.encodePaint(op)!)!;
      expect(decoded.anonymousAuthor, isTrue);
      expect(decoded.authorId, 0);
    });

    test('encode rejects out-of-range x/y/color via ArgumentError', () {
      expect(
        () => CanvasCodec.encodePaint(
          const CanvasPaintOp(
            canvasId: 0,
            // One past the max (cellCoordMax = 63 for the v0.1 grid).
            x: 64,
            y: 0,
            color: 0,
            authorId: 0,
            opTs: 0,
            opSeq: 0,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => CanvasCodec.encodePaint(
          const CanvasPaintOp(
            canvasId: 0,
            x: 0,
            y: 0,
            color: 64,
            authorId: 0,
            opTs: 0,
            opSeq: 0,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('encode rejects anonymous=true with non-zero author', () {
      expect(
        () => CanvasCodec.encodePaint(
          const CanvasPaintOp(
            canvasId: 0,
            x: 0,
            y: 0,
            color: 0,
            authorId: 42,
            opTs: 0,
            opSeq: 0,
            anonymousAuthor: true,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('decode rejects wrong magic / version / op_type', () {
      final ok = CanvasCodec.encodePaint(
        const CanvasPaintOp(
          canvasId: 1,
          x: 0,
          y: 0,
          color: 0,
          authorId: 1,
          opTs: 1,
          opSeq: 0,
        ),
      )!;

      final badMagic = Uint8List.fromList(ok)..[0] = 0xAB;
      expect(CanvasCodec.decodePaint(badMagic), isNull);

      final badVersion = Uint8List.fromList(ok)..[1] = 0x02;
      expect(CanvasCodec.decodePaint(badVersion), isNull);

      final wrongOpType = Uint8List.fromList(ok)..[2] = 0x02;
      expect(CanvasCodec.decodePaint(wrongOpType), isNull);
    });

    test('decode rejects truncation of every kind', () {
      final ok = CanvasCodec.encodePaint(
        const CanvasPaintOp(
          canvasId: 0,
          x: 0,
          y: 0,
          color: 0,
          authorId: 0,
          opTs: 0,
          opSeq: 0,
        ),
      )!;
      for (var len = 0; len < ok.length; len++) {
        expect(
          CanvasCodec.decodePaint(Uint8List.fromList(ok.sublist(0, len))),
          isNull,
          reason: 'truncation at $len bytes should reject',
        );
      }
      // One extra byte also rejects (length check is exact).
      final tooLong = Uint8List.fromList([...ok, 0]);
      expect(CanvasCodec.decodePaint(tooLong), isNull);
    });

    test('decode rejects reserved color bits', () {
      final ok = CanvasCodec.encodePaint(
        const CanvasPaintOp(
          canvasId: 0,
          x: 0,
          y: 0,
          color: 0,
          authorId: 0,
          opTs: 0,
          opSeq: 0,
        ),
      )!;
      ok[14] = 0x80; // bit 7 set
      expect(CanvasCodec.decodePaint(ok), isNull);
    });

    test('decode rejects reserved flag bits', () {
      final ok = CanvasCodec.encodePaint(
        const CanvasPaintOp(
          canvasId: 0,
          x: 0,
          y: 0,
          color: 0,
          authorId: 0,
          opTs: 0,
          opSeq: 0,
        ),
      )!;
      ok[3] = 0x04; // bit 2 reserved
      expect(CanvasCodec.decodePaint(ok), isNull);
    });

    test('decode rejects unexpected batch flag on a paint frame', () {
      final ok = CanvasCodec.encodePaint(
        const CanvasPaintOp(
          canvasId: 0,
          x: 0,
          y: 0,
          color: 0,
          authorId: 0,
          opTs: 0,
          opSeq: 0,
        ),
      )!;
      ok[3] = 0x01; // batch bit set
      expect(CanvasCodec.decodePaint(ok), isNull);
    });
  });

  group('paint_batch (action 0x0002)', () {
    CanvasPaintBatchOp mkBatch(int n) => CanvasPaintBatchOp(
      canvasId: 1,
      authorId: 0xABCDEF01,
      batchTs: 0x12345678,
      batchSeq: 7,
      ops: List<CanvasBatchedPaintRecord>.generate(
        n,
        (i) => CanvasBatchedPaintRecord(
          x: i % 128,
          y: (i * 3) % 128,
          color: i % 64,
          tsOffset: ((i % 5) - 2),
          opSeq: i & 0xFF,
        ),
      ),
    );

    test('byte-exact vector for N=1', () {
      const canvasId = 0x0102030405060708;
      final batch = CanvasPaintBatchOp(
        canvasId: canvasId,
        authorId: 0xAABBCCDD,
        batchTs: 0x11223344,
        batchSeq: 8,
        ops: const [
          CanvasBatchedPaintRecord(
            x: 5,
            y: 6,
            color: 7,
            tsOffset: -1,
            opSeq: 9,
          ),
        ],
      );
      final encoded = CanvasCodec.encodePaintBatch(batch)!;
      final expected = <int>[
        0xCA,
        0x01,
        0x02,
        0x01, //                 magic, version, op_type, flags (batch bit)
        ..._u64LeBytes(canvasId),
        0xDD, 0xCC, 0xBB, 0xAA, //                 author u32 LE
        0x44, 0x33, 0x22, 0x11, //                 batch_ts u32 LE
        1, 8, //                                   op_count, batch_seq
        5,
        6,
        7,
        0xFF,
        9, //                       op record (tsOffset=-1 = 0xFF)
      ];
      expect(encoded, equals(Uint8List.fromList(expected)));
    });

    test('round-trip for N=1, N=21 boundaries', () {
      for (final n in const [1, 21]) {
        final batch = mkBatch(n);
        final decoded = CanvasCodec.decodePaintBatch(
          CanvasCodec.encodePaintBatch(batch)!,
        )!;
        expect(decoded.ops.length, n);
        for (var i = 0; i < n; i++) {
          expect(decoded.ops[i].x, batch.ops[i].x);
          expect(decoded.ops[i].y, batch.ops[i].y);
          expect(decoded.ops[i].color, batch.ops[i].color);
          expect(decoded.ops[i].tsOffset, batch.ops[i].tsOffset);
          expect(decoded.ops[i].opSeq, batch.ops[i].opSeq);
        }
      }
    });

    test('encode rejects N=0 with null return', () {
      const batch = CanvasPaintBatchOp(
        canvasId: 0,
        authorId: 0,
        batchTs: 0,
        batchSeq: 0,
        ops: [],
      );
      expect(CanvasCodec.encodePaintBatch(batch), isNull);
    });

    test('encode rejects N=22 with null return', () {
      final batch = mkBatch(22);
      expect(CanvasCodec.encodePaintBatch(batch), isNull);
    });

    test('decode rejects on-wire op_count=0', () {
      // Build a 22-byte minimum payload with op_count = 0.
      final buf = Uint8List(22)
        ..[0] = 0xCA
        ..[1] = 0x01
        ..[2] = 0x02
        ..[3] = 0x01
        ..[20] = 0;
      expect(CanvasCodec.decodePaintBatch(buf), isNull);
    });

    test('decode rejects on-wire op_count=22', () {
      final body = List<int>.filled(5 * 22, 0);
      final buf = Uint8List(22 + body.length)
        ..[0] = 0xCA
        ..[1] = 0x01
        ..[2] = 0x02
        ..[3] = 0x01
        ..[20] = 22;
      // Set body bytes to zero (in-range coords / colors).
      buf.setRange(22, buf.length, body);
      expect(CanvasCodec.decodePaintBatch(buf), isNull);
    });

    test('decode rejects payload length mismatch with op_count', () {
      // Encode a real N=2 batch, then truncate the trailing record.
      final batch = mkBatch(2);
      final ok = CanvasCodec.encodePaintBatch(batch)!;
      final truncated = Uint8List.fromList(ok.sublist(0, ok.length - 1));
      expect(CanvasCodec.decodePaintBatch(truncated), isNull);
    });

    test('decode rejects reserved color bits in a packed record', () {
      final batch = mkBatch(1);
      final ok = CanvasCodec.encodePaintBatch(batch)!;
      // 22 = header end. First record starts at 22; color is at +2 → 24.
      ok[22 + 2] = 0x80;
      expect(CanvasCodec.decodePaintBatch(ok), isNull);
    });
  });

  group('canvas_digest (action 0x0003)', () {
    test('byte-exact length and offsets', () {
      final globalDigest = Uint8List.fromList(
        List<int>.generate(16, (i) => 0xA0 + i),
      );
      // v0.1 64×64 → 4 tiles × 8 bytes = 32 byte tile digest blob.
      // Constants derive from CanvasGeometry so future geometry
      // changes only require updating that one place.
      final tileDigests = Uint8List.fromList(
        List<int>.generate(CanvasDigestSizes.tilesConcatenatedBytes, (i) => i),
      );
      const canvasId = 0xCAFEBABE12345678;
      final op = CanvasDigestOp(
        canvasId: canvasId,
        globalDigest: globalDigest,
        cellCount: 0x11223344,
        tileDigests: tileDigests,
      );
      final encoded = CanvasCodec.encodeCanvasDigest(op)!;
      expect(encoded.length, CanvasDigestSizes.totalDigestPayloadBytes);
      // Prefix
      expect(encoded.sublist(0, 12), <int>[
        0xCA,
        0x01,
        0x03,
        0x00,
        ..._u64LeBytes(canvasId),
      ]);
      // global_digest
      expect(encoded.sublist(12, 28), globalDigest);
      // cell_count u32 LE at offset 28
      expect(encoded.sublist(28, 32), _u32LeBytes(0x11223344));
      // tile_digests fills the remainder of the payload
      expect(
        encoded.sublist(32, CanvasDigestSizes.totalDigestPayloadBytes),
        tileDigests,
      );
    });

    test('round-trip', () {
      final globalDigest = Uint8List.fromList(List<int>.filled(16, 0xAA));
      final tileDigests = Uint8List.fromList(
        List<int>.filled(CanvasDigestSizes.tilesConcatenatedBytes, 0xBB),
      );
      final op = CanvasDigestOp(
        canvasId: 1,
        globalDigest: globalDigest,
        cellCount: 100,
        tileDigests: tileDigests,
      );
      final decoded = CanvasCodec.decodeCanvasDigest(
        CanvasCodec.encodeCanvasDigest(op)!,
      )!;
      expect(decoded.canvasId, 1);
      expect(decoded.cellCount, 100);
      expect(decoded.globalDigest, globalDigest);
      expect(decoded.tileDigests, tileDigests);
    });

    test('encode rejects wrong digest blob lengths via null', () {
      // Wrong global digest length (15 ≠ 16).
      expect(
        CanvasCodec.encodeCanvasDigest(
          CanvasDigestOp(
            canvasId: 0,
            globalDigest: Uint8List(15),
            cellCount: 0,
            tileDigests: Uint8List(CanvasDigestSizes.tilesConcatenatedBytes),
          ),
        ),
        isNull,
      );
      // Wrong tile-digests blob length (one byte short).
      expect(
        CanvasCodec.encodeCanvasDigest(
          CanvasDigestOp(
            canvasId: 0,
            globalDigest: Uint8List(16),
            cellCount: 0,
            tileDigests: Uint8List(
              CanvasDigestSizes.tilesConcatenatedBytes - 1,
            ),
          ),
        ),
        isNull,
      );
    });

    test('decode rejects length mismatch', () {
      final total = CanvasDigestSizes.totalDigestPayloadBytes;
      expect(CanvasCodec.decodeCanvasDigest(Uint8List(total - 1)), isNull);
      expect(CanvasCodec.decodeCanvasDigest(Uint8List(total + 1)), isNull);
    });
  });

  group('sync_request (action 0x0004)', () {
    test('byte-exact for tile (1,1) — bottom-right of v0.1 64×64 grid', () {
      const canvasId = 0xAA55AA55AA55AA55;
      const op = CanvasSyncRequestOp(canvasId: canvasId, tileX: 1, tileY: 1);
      final encoded = CanvasCodec.encodeSyncRequest(op)!;
      final expected = <int>[
        0xCA, 0x01, 0x04, 0x00,
        ..._u64LeBytes(canvasId),
        32, 32, 32 + 31, 32 + 31, // x0,y0,x1,y1
        0, 0, // reserved
      ];
      expect(encoded, equals(Uint8List.fromList(expected)));
    });

    test('round-trip for every valid tile (0..tilesPerRow-1 in each axis)', () {
      for (var ty = 0; ty < CanvasGeometry.tilesPerRow; ty++) {
        for (var tx = 0; tx < CanvasGeometry.tilesPerRow; tx++) {
          final encoded = CanvasCodec.encodeSyncRequest(
            CanvasSyncRequestOp(canvasId: 7, tileX: tx, tileY: ty),
          )!;
          final decoded = CanvasCodec.decodeSyncRequest(encoded)!;
          expect(decoded.tileX, tx);
          expect(decoded.tileY, ty);
          expect(decoded.x0, tx * CanvasGeometry.tileSize);
          expect(decoded.y0, ty * CanvasGeometry.tileSize);
          expect(decoded.x1, tx * CanvasGeometry.tileSize + 31);
          expect(decoded.y1, ty * CanvasGeometry.tileSize + 31);
        }
      }
    });

    test('decode rejects non-tile-aligned rects', () {
      // 18 bytes with valid prefix, x0=1 (misaligned).
      final buf = Uint8List(18)
        ..[0] = 0xCA
        ..[1] = 0x01
        ..[2] = 0x04
        ..[12] = 1
        ..[13] = 0
        ..[14] = 32
        ..[15] = 31;
      expect(CanvasCodec.decodeSyncRequest(buf), isNull);
    });

    test('decode rejects wrong span (x1 != x0+31)', () {
      final buf = Uint8List(18)
        ..[0] = 0xCA
        ..[1] = 0x01
        ..[2] = 0x04
        ..[12] = 0
        ..[13] = 0
        ..[14] =
            30 // wrong
        ..[15] = 31;
      expect(CanvasCodec.decodeSyncRequest(buf), isNull);
    });

    test('decode rejects non-zero reserved field', () {
      final buf = Uint8List(18)
        ..[0] = 0xCA
        ..[1] = 0x01
        ..[2] = 0x04
        ..[12] = 0
        ..[13] = 0
        ..[14] = 31
        ..[15] = 31
        ..[16] = 1; // non-zero reserved
      expect(CanvasCodec.decodeSyncRequest(buf), isNull);
    });

    test('encode rejects out-of-range tileX / tileY', () {
      expect(
        () => CanvasCodec.encodeSyncRequest(
          const CanvasSyncRequestOp(canvasId: 0, tileX: 4, tileY: 0),
        ),
        throwsArgumentError,
      );
      expect(
        () => CanvasCodec.encodeSyncRequest(
          const CanvasSyncRequestOp(canvasId: 0, tileX: 0, tileY: -1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('sync_response (action 0x0005) — RLE encoding 0', () {
    test('byte-exact happy path: 3 runs', () {
      const canvasId = 0x33;
      final op = CanvasSyncResponseOp(
        canvasId: canvasId,
        tileX: 0,
        tileY: 0,
        body: const CanvasSyncResponseRleBody(
          runs: [
            CanvasSyncResponseRun(length: 200, color: 0),
            CanvasSyncResponseRun(length: 100, color: 5),
            CanvasSyncResponseRun(length: 50, color: 12),
          ],
        ),
      );
      final encoded = CanvasCodec.encodeSyncResponse(op)!;
      final expected = <int>[
        0xCA, 0x01, 0x05, 0x00,
        ..._u64LeBytes(canvasId),
        0, 0, // tile_x, tile_y
        0, 0, 1, // encoding=0, band_index=0, total_bands=1
        0, //       reserved
        200, 0, 100, 5, 50, 12, // 3 RLE runs
      ];
      expect(encoded, equals(Uint8List.fromList(expected)));
    });

    test('round-trip for 1 run and the 88-run upper bound', () {
      for (final n in const [1, CanvasWireFormat.syncResponseMaxRunsPerFrame]) {
        final runs = List<CanvasSyncResponseRun>.generate(
          n,
          (i) => CanvasSyncResponseRun(length: 1 + (i % 255), color: i % 64),
        );
        final op = CanvasSyncResponseOp(
          canvasId: 1,
          tileX: 1,
          tileY: 1,
          body: CanvasSyncResponseRleBody(runs: runs),
        );
        final decoded = CanvasCodec.decodeSyncResponse(
          CanvasCodec.encodeSyncResponse(op)!,
        )!;
        expect(decoded.tileX, op.tileX);
        expect(decoded.tileY, op.tileY);
        final body = decoded.body as CanvasSyncResponseRleBody;
        expect(body.runs.length, n);
        for (var i = 0; i < n; i++) {
          expect(body.runs[i].length, runs[i].length);
          expect(body.runs[i].color, runs[i].color);
        }
      }
    });

    test('encode rejects 89 runs (over the per-frame cap)', () {
      final runs = List<CanvasSyncResponseRun>.generate(
        CanvasWireFormat.syncResponseMaxRunsPerFrame + 1,
        (_) => const CanvasSyncResponseRun(length: 1, color: 0),
      );
      expect(
        CanvasCodec.encodeSyncResponse(
          CanvasSyncResponseOp(
            canvasId: 0,
            tileX: 0,
            tileY: 0,
            body: CanvasSyncResponseRleBody(runs: runs),
          ),
        ),
        isNull,
      );
    });

    test('encode rejects zero-length run', () {
      expect(
        CanvasCodec.encodeSyncResponse(
          const CanvasSyncResponseOp(
            canvasId: 0,
            tileX: 0,
            tileY: 0,
            body: CanvasSyncResponseRleBody(
              runs: [CanvasSyncResponseRun(length: 0, color: 1)],
            ),
          ),
        ),
        isNull,
      );
    });

    test('decode rejects RLE body with reserved color bits', () {
      // 18-byte header + 1 RLE run with color = 0x80.
      final buf = Uint8List(20)
        ..[0] = 0xCA
        ..[1] = 0x01
        ..[2] = 0x05
        ..[14] =
            0 // encoding 0
        ..[15] = 0
        ..[16] =
            1 // total_bands
        ..[18] =
            1 // length
        ..[19] = 0x80; // bad color
      expect(CanvasCodec.decodeSyncResponse(buf), isNull);
    });
  });

  group(
    'sync_response (action 0x0005) — raw band encoding 1 (deterministic)',
    () {
      test('byte-exact band-0 header', () {
        const canvasId = 0x44;
        final cells = Uint8List(128);
        final op = CanvasSyncResponseOp(
          canvasId: canvasId,
          tileX: 0,
          tileY: 0,
          body: CanvasSyncResponseRawBandBody(bandIndex: 0, cells: cells),
        );
        final encoded = CanvasCodec.encodeSyncResponse(op)!;
        expect(encoded.length, 18 + 128);
        expect(encoded.sublist(0, 12), <int>[
          0xCA,
          0x01,
          0x05,
          0x00,
          ..._u64LeBytes(canvasId),
        ]);
        expect(encoded[12], 0); // tile_x
        expect(encoded[13], 0); // tile_y
        expect(encoded[14], 1); // encoding=1
        expect(encoded[15], 0); // band_index=0
        expect(encoded[16], 8); // total_bands=8
        expect(encoded[17], 0); // reserved
      });

      test('round-trip for every band index 0..7', () {
        for (var b = 0; b < 8; b++) {
          final cells = Uint8List.fromList(
            List<int>.generate(128, (i) => (i + b) % 64),
          );
          final op = CanvasSyncResponseOp(
            canvasId: 9,
            tileX: 1,
            tileY: 1,
            body: CanvasSyncResponseRawBandBody(bandIndex: b, cells: cells),
          );
          final decoded = CanvasCodec.decodeSyncResponse(
            CanvasCodec.encodeSyncResponse(op)!,
          )!;
          final body = decoded.body as CanvasSyncResponseRawBandBody;
          expect(body.bandIndex, b);
          expect(body.cells, cells);
        }
      });

      test('encode rejects 127-cell raw body via ArgumentError', () {
        expect(
          () => CanvasCodec.encodeSyncResponse(
            CanvasSyncResponseOp(
              canvasId: 0,
              tileX: 0,
              tileY: 0,
              body: CanvasSyncResponseRawBandBody(
                bandIndex: 0,
                cells: Uint8List(127),
              ),
            ),
          ),
          throwsArgumentError,
        );
      });

      test('encode rejects out-of-range band index', () {
        expect(
          () => CanvasCodec.encodeSyncResponse(
            CanvasSyncResponseOp(
              canvasId: 0,
              tileX: 0,
              tileY: 0,
              body: CanvasSyncResponseRawBandBody(
                bandIndex: 8,
                cells: Uint8List(128),
              ),
            ),
          ),
          throwsArgumentError,
        );
      });

      test('decode rejects raw band body with reserved color bits', () {
        // Encoder validates every cell and throws on the first reserved
        // bit it sees.
        final badCells = Uint8List(128);
        badCells[0] = 0x80;
        expect(
          () => CanvasCodec.encodeSyncResponse(
            CanvasSyncResponseOp(
              canvasId: 0,
              tileX: 0,
              tileY: 0,
              body: CanvasSyncResponseRawBandBody(
                bandIndex: 0,
                cells: badCells,
              ),
            ),
          ),
          throwsArgumentError,
        );

        // A hand-built buffer that smuggles the bad bit past the
        // encoder MUST still be rejected at decode time.
        final buf = Uint8List(146)
          ..[0] = 0xCA
          ..[1] = 0x01
          ..[2] = 0x05
          ..[14] =
              1 // encoding=1
          ..[15] =
              0 // band_index
          ..[16] =
              8 // total_bands
          ..[18] = 0x80; // first cell has bit 7 set
        expect(CanvasCodec.decodeSyncResponse(buf), isNull);
      });

      test('worst-case checkerboard tile reconstructs across 8 bands', () {
        // Reference 32×32 checkerboard: cell (x,y) → ((x + y) & 1) ? 1 : 2.
        // Verifies the bandwidth invariant from CANVAS_V0_1.md I1:
        // any tile, including a pathological pattern, reconstructs
        // deterministically through 8 raw bands.
        int reference(int x, int y) => ((x + y) & 1) == 0 ? 1 : 2;

        // Sender builds 8 raw-band frames for the same tile.
        final frames = <Uint8List>[];
        for (var band = 0; band < 8; band++) {
          final cells = Uint8List(128);
          for (var row = 0; row < 4; row++) {
            for (var col = 0; col < 32; col++) {
              final globalX = col; // tile (0,0): cell x = col
              final globalY = band * 4 + row;
              cells[row * 32 + col] = reference(globalX, globalY);
            }
          }
          final encoded = CanvasCodec.encodeSyncResponse(
            CanvasSyncResponseOp(
              canvasId: 0xC0DE,
              tileX: 0,
              tileY: 0,
              body: CanvasSyncResponseRawBandBody(
                bandIndex: band,
                cells: cells,
              ),
            ),
          )!;
          expect(encoded.length, 18 + 128);
          frames.add(encoded);
        }

        // Receiver applies bands in scrambled order to confirm
        // out-of-order arrival is fine.
        final scrambled = List<Uint8List>.from(frames);
        scrambled.shuffle(Random(0xBEEF));

        final reconstructed = List<List<int>>.generate(
          32,
          (_) => List<int>.filled(32, -1),
        );
        for (final frame in scrambled) {
          final decoded = CanvasCodec.decodeSyncResponse(frame)!;
          expect(decoded.tileX, 0);
          expect(decoded.tileY, 0);
          final body = decoded.body as CanvasSyncResponseRawBandBody;
          for (var row = 0; row < 4; row++) {
            for (var col = 0; col < 32; col++) {
              final globalY = body.bandIndex * 4 + row;
              reconstructed[col][globalY] = body.cells[row * 32 + col];
            }
          }
        }

        // Every cell of the tile equals the reference checkerboard,
        // proving the deterministic path can reconstruct any pattern.
        for (var y = 0; y < 32; y++) {
          for (var x = 0; x < 32; x++) {
            expect(
              reconstructed[x][y],
              reference(x, y),
              reason: 'mismatch at ($x,$y)',
            );
          }
        }
      });
    },
  );

  group('canvas_info (action 0x0006)', () {
    test('request byte-exact + round-trip', () {
      const canvasId = 0xDEADBEEFFEEDFACE;
      const req = CanvasInfoRequest(canvasId: canvasId);
      final encoded = CanvasCodec.encodeCanvasInfoRequest(req)!;
      final expected = <int>[
        0xCA,
        0x01,
        0x06,
        0x00,
        ..._u64LeBytes(canvasId),
        0,
        0,
        0,
        0,
      ];
      expect(encoded, equals(Uint8List.fromList(expected)));
      final decoded = CanvasCodec.decodeCanvasInfoRequest(encoded)!;
      expect(decoded.canvasId, canvasId);
    });

    test('response byte-exact + round-trip', () {
      final nameHint = Uint8List.fromList(<int>[
        0x50, 0x72, 0x69, 0x6D, 0x61, 0x72, 0x79, 0x00, // "Primary\0"
      ]);
      final resp = CanvasInfoResponse(
        canvasId: 0xAB,
        width: 128,
        height: 128,
        paletteId: 1,
        status: 0,
        createdAt: 0x10000000,
        ownerId: 0x20000000,
        cellCount: 0x30000000,
        nameHint: nameHint,
      );
      final encoded = CanvasCodec.encodeCanvasInfoResponse(resp)!;
      expect(encoded.length, 36);
      // Prefix + body slices match exactly.
      expect(encoded.sublist(0, 12), <int>[
        0xCA,
        0x01,
        0x06,
        0x00,
        ..._u64LeBytes(0xAB),
      ]);
      expect(encoded[12], 128);
      expect(encoded[13], 128);
      expect(encoded[14], 1);
      expect(encoded[15], 0);
      expect(encoded.sublist(16, 20), _u32LeBytes(0x10000000));
      expect(encoded.sublist(20, 24), _u32LeBytes(0x20000000));
      expect(encoded.sublist(24, 28), _u32LeBytes(0x30000000));
      expect(encoded.sublist(28, 36), nameHint);

      final decoded = CanvasCodec.decodeCanvasInfoResponse(encoded)!;
      expect(decoded.canvasId, 0xAB);
      expect(decoded.width, 128);
      expect(decoded.paletteId, 1);
      expect(decoded.createdAt, 0x10000000);
      expect(decoded.nameHint, nameHint);
    });

    test('response encoder rejects wrong-length name_hint', () {
      expect(
        () => CanvasCodec.encodeCanvasInfoResponse(
          CanvasInfoResponse(
            canvasId: 0,
            width: 128,
            height: 128,
            paletteId: 1,
            status: 0,
            createdAt: 0,
            ownerId: 0,
            cellCount: 0,
            nameHint: Uint8List(7), // wrong
          ),
        ),
        throwsArgumentError,
      );
    });

    test('request decoder rejects non-zero reserved field', () {
      final ok = CanvasCodec.encodeCanvasInfoRequest(
        const CanvasInfoRequest(canvasId: 1),
      )!;
      ok[12] = 1;
      expect(CanvasCodec.decodeCanvasInfoRequest(ok), isNull);
    });
  });

  group('u64 canvas_id endianness pinned across actions', () {
    test('byte 4..11 is little-endian on every action', () {
      const canvasId = 0x0102030405060708;
      final expected = _u64LeBytes(canvasId);

      final paintBytes = CanvasCodec.encodePaint(
        const CanvasPaintOp(
          canvasId: canvasId,
          x: 0,
          y: 0,
          color: 0,
          authorId: 0,
          opTs: 0,
          opSeq: 0,
        ),
      )!;
      expect(paintBytes.sublist(4, 12), expected);

      final batchBytes = CanvasCodec.encodePaintBatch(
        CanvasPaintBatchOp(
          canvasId: canvasId,
          authorId: 0,
          batchTs: 0,
          batchSeq: 0,
          ops: const [
            CanvasBatchedPaintRecord(
              x: 0,
              y: 0,
              color: 0,
              tsOffset: 0,
              opSeq: 0,
            ),
          ],
        ),
      )!;
      expect(batchBytes.sublist(4, 12), expected);

      final digestBytes = CanvasCodec.encodeCanvasDigest(
        CanvasDigestOp(
          canvasId: canvasId,
          globalDigest: Uint8List(16),
          cellCount: 0,
          tileDigests: Uint8List(CanvasDigestSizes.tilesConcatenatedBytes),
        ),
      )!;
      expect(digestBytes.sublist(4, 12), expected);

      final reqBytes = CanvasCodec.encodeSyncRequest(
        const CanvasSyncRequestOp(canvasId: canvasId, tileX: 0, tileY: 0),
      )!;
      expect(reqBytes.sublist(4, 12), expected);

      final infoReqBytes = CanvasCodec.encodeCanvasInfoRequest(
        const CanvasInfoRequest(canvasId: canvasId),
      )!;
      expect(infoReqBytes.sublist(4, 12), expected);
    });
  });
}
