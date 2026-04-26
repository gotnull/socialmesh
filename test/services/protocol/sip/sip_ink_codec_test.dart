// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/sip_ink_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_ink_decoder.dart';
import 'package:socialmesh/services/protocol/sip/sip_ink_encoder.dart';
import 'package:socialmesh/services/protocol/sip/sip_ink_payload.dart';

void main() {
  group('SipInkEncoder', () {
    test('encodes a single straight stroke into the spec layout', () {
      final sketch = SipInkSketch(
        canvasSize: SipInkConstants.canvas64,
        strokes: [
          SipInkStroke(
            width: 2,
            points: const [
              SipInkPoint(10, 10),
              SipInkPoint(13, 12),
              SipInkPoint(15, 15),
            ],
          ),
        ],
      );

      final result = SipInkEncoder.encode(sketch);
      expect(result.isOk, isTrue);
      expect(
        result.bytes,
        equals(
          Uint8List.fromList([
            // global header
            SipInkConstants.typeAndVersionV1, // 0x11
            0x00, // flags: canvas64
            0x01, // stroke_count
            0x03, // total_point_count
            // stroke 0
            0x02, // width
            0x03, // point_count
            0x0A, // first_x
            0x0A, // first_y
            // packed deltas: (dx+8)<<4 | (dy+8)
            // (3,2) -> (11<<4)|10 = 0xBA
            0xBA,
            // (2,3) -> (10<<4)|11 = 0xAB
            0xAB,
          ]),
        ),
      );
    });

    test('rejects empty sketch', () {
      final result = SipInkEncoder.encode(
        const SipInkSketch(canvasSize: 64, strokes: []),
      );
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipInkEncodeError.empty));
    });

    test('rejects too many strokes', () {
      final strokes = List.generate(
        SipInkConstants.maxStrokes + 1,
        (i) => SipInkStroke(
          width: 1,
          points: [SipInkPoint(i, i), SipInkPoint(i + 1, i + 1)],
        ),
      );
      final result = SipInkEncoder.encode(
        SipInkSketch(canvasSize: 64, strokes: strokes),
      );
      expect(result.error, equals(SipInkEncodeError.tooManyStrokes));
    });

    test('rejects too many points', () {
      // 1 stroke with 65 points -> > maxTotalPoints (64).
      final pts = List.generate(65, (i) => SipInkPoint(i % 8, i ~/ 8));
      final result = SipInkEncoder.encode(
        SipInkSketch(
          canvasSize: 64,
          strokes: [SipInkStroke(width: 1, points: pts)],
        ),
      );
      expect(result.error, equals(SipInkEncodeError.tooManyPoints));
    });

    test('rejects point out of bounds for canvas64', () {
      final result = SipInkEncoder.encode(
        SipInkSketch(
          canvasSize: 64,
          strokes: [
            SipInkStroke(
              width: 1,
              points: const [SipInkPoint(0, 0), SipInkPoint(64, 0)],
            ),
          ],
        ),
      );
      expect(result.error, equals(SipInkEncodeError.pointOutOfBounds));
    });

    test('rejects delta overflow', () {
      final result = SipInkEncoder.encode(
        SipInkSketch(
          canvasSize: 64,
          strokes: [
            SipInkStroke(
              width: 1,
              // dx=10 > 7
              points: const [SipInkPoint(0, 0), SipInkPoint(10, 0)],
            ),
          ],
        ),
      );
      expect(result.error, equals(SipInkEncodeError.deltaOverflow));
    });

    test('rejects invalid width', () {
      final result = SipInkEncoder.encode(
        SipInkSketch(
          canvasSize: 64,
          strokes: [
            SipInkStroke(
              width: 5,
              points: const [SipInkPoint(0, 0), SipInkPoint(1, 1)],
            ),
          ],
        ),
      );
      expect(result.error, equals(SipInkEncodeError.invalidWidth));
    });

    test('rejects invalid canvas size', () {
      final result = SipInkEncoder.encode(
        SipInkSketch(
          canvasSize: 96,
          strokes: [
            SipInkStroke(
              width: 1,
              points: const [SipInkPoint(0, 0), SipInkPoint(1, 1)],
            ),
          ],
        ),
      );
      expect(result.error, equals(SipInkEncodeError.invalidCanvas));
    });

    test('rejects stroke shorter than min points', () {
      final result = SipInkEncoder.encode(
        SipInkSketch(
          canvasSize: 64,
          strokes: [
            SipInkStroke(width: 1, points: const [SipInkPoint(0, 0)]),
          ],
        ),
      );
      expect(result.error, equals(SipInkEncodeError.strokeTooShort));
    });

    test('canvas128 sets the flag bit', () {
      final result = SipInkEncoder.encode(
        SipInkSketch(
          canvasSize: 128,
          strokes: [
            SipInkStroke(
              width: 1,
              points: const [SipInkPoint(100, 100), SipInkPoint(101, 101)],
            ),
          ],
        ),
      );
      expect(result.isOk, isTrue);
      expect(result.bytes![1] & SipInkConstants.flagCanvas128, isNonZero);
    });

    test('determinism: same input produces same bytes', () {
      final sketch = SipInkSketch(
        canvasSize: 64,
        strokes: [
          SipInkStroke(
            width: 3,
            points: const [
              SipInkPoint(5, 5),
              SipInkPoint(8, 7),
              SipInkPoint(10, 10),
              SipInkPoint(12, 14),
            ],
          ),
          SipInkStroke(
            width: 1,
            points: const [SipInkPoint(20, 20), SipInkPoint(22, 23)],
          ),
        ],
      );
      final a = SipInkEncoder.encode(sketch).bytes!;
      final b = SipInkEncoder.encode(sketch).bytes!;
      expect(a, equals(b));
    });
  });

  group('SipInkDecoder', () {
    test('round-trips with encoder', () {
      final original = SipInkSketch(
        canvasSize: 64,
        strokes: [
          SipInkStroke(
            width: 4,
            points: const [
              SipInkPoint(1, 2),
              SipInkPoint(3, 4),
              SipInkPoint(7, 5),
              SipInkPoint(10, 6),
            ],
          ),
          SipInkStroke(
            width: 1,
            points: const [
              SipInkPoint(40, 40),
              SipInkPoint(42, 41),
              SipInkPoint(45, 39),
            ],
          ),
        ],
      );
      final encoded = SipInkEncoder.encode(original).bytes!;
      final decoded = SipInkDecoder.decode(encoded);
      expect(decoded.isOk, isTrue);
      expect(decoded.sketch!.canvasSize, equals(original.canvasSize));
      expect(decoded.sketch!.strokes.length, equals(original.strokes.length));
      for (var i = 0; i < original.strokes.length; i++) {
        final a = original.strokes[i];
        final b = decoded.sketch!.strokes[i];
        expect(b.width, equals(a.width));
        expect(b.points, equals(a.points));
      }
    });

    test('rejects underflow', () {
      final r = SipInkDecoder.decode(Uint8List.fromList([0x11, 0x00]));
      expect(r.error, equals(SipInkDecodeError.underflow));
    });

    test('rejects unsupported version', () {
      final r = SipInkDecoder.decode(
        Uint8List.fromList([
          (SipInkConstants.typeCode << 4) | 0x2, // v2
          0x00,
          0x01,
          0x02,
        ]),
      );
      expect(r.error, equals(SipInkDecodeError.unsupportedVersion));
    });

    test('rejects unknown type', () {
      final r = SipInkDecoder.decode(
        Uint8List.fromList([(0x2 << 4) | 0x1, 0x00, 0x01, 0x02]),
      );
      expect(r.error, equals(SipInkDecodeError.unsupportedType));
    });

    test('rejects reserved flag bits', () {
      final r = SipInkDecoder.decode(
        Uint8List.fromList([
          SipInkConstants.typeAndVersionV1,
          0x80, // reserved bit set
          0x01,
          0x02,
        ]),
      );
      expect(r.error, equals(SipInkDecodeError.reservedFlagsSet));
    });

    test('rejects too many strokes header', () {
      final r = SipInkDecoder.decode(
        Uint8List.fromList([
          SipInkConstants.typeAndVersionV1,
          0x00,
          SipInkConstants.maxStrokes + 1,
          0x02,
        ]),
      );
      expect(r.error, equals(SipInkDecodeError.tooManyStrokes));
    });

    test('rejects too many points header', () {
      final r = SipInkDecoder.decode(
        Uint8List.fromList([
          SipInkConstants.typeAndVersionV1,
          0x00,
          0x01,
          SipInkConstants.maxTotalPoints + 1,
        ]),
      );
      expect(r.error, equals(SipInkDecodeError.tooManyPoints));
    });

    test('rejects point count mismatch', () {
      // Header declares total=5 but stroke declares 2 points.
      final r = SipInkDecoder.decode(
        Uint8List.fromList([
          SipInkConstants.typeAndVersionV1,
          0x00,
          0x01,
          0x05,
          0x01,
          0x02,
          0x00,
          0x00,
          0x88, // delta (0,0)
        ]),
      );
      expect(r.error, equals(SipInkDecodeError.pointCountMismatch));
    });

    test('rejects truncated stroke header', () {
      final r = SipInkDecoder.decode(
        Uint8List.fromList([
          SipInkConstants.typeAndVersionV1,
          0x00,
          0x01,
          0x02,
          0x01, // width only — missing point_count, first_x, first_y
        ]),
      );
      expect(r.error, equals(SipInkDecodeError.underflow));
    });

    test('rejects delta walk that exits canvas', () {
      // Start at (0,0), then dx=-1 lands at (-1,0).
      final r = SipInkDecoder.decode(
        Uint8List.fromList([
          SipInkConstants.typeAndVersionV1,
          0x00,
          0x01,
          0x02,
          0x01,
          0x02,
          0x00,
          0x00,
          0x78, // (dx=-1, dy=0)
        ]),
      );
      expect(r.error, equals(SipInkDecodeError.pointOutOfBounds));
    });

    test('never throws on random garbage', () {
      // Fuzz with deterministic byte sequences. None should throw; all
      // must produce a typed error or a successful decode.
      for (var seed = 0; seed < 64; seed++) {
        final bytes = Uint8List.fromList(
          List.generate(20, (i) => (seed * 31 + i * 7) & 0xFF),
        );
        // No throw.
        SipInkDecoder.decode(bytes);
      }
    });
  });
}
