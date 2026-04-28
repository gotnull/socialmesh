// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/sip_ink_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_ink_decoder.dart';
import 'package:socialmesh/services/protocol/sip/sip_ink_encoder.dart';
import 'package:socialmesh/services/protocol/sip/sip_ink_simplifier.dart';

SipInkRawStroke _smiley(int width) {
  // A short freehand-ish path that fits comfortably on canvas64.
  final pts = <({double x, double y})>[];
  for (var i = 0; i < 12; i++) {
    pts.add((x: 10.0 + i * 2.4, y: 20.0 + (i.isEven ? 0.1 : -0.1)));
  }
  return SipInkRawStroke(width: width, points: pts);
}

void main() {
  group('SipInkSimplifier', () {
    test('rejects empty input', () {
      final r = SipInkSimplifier.simplify(rawStrokes: [], canvasSize: 64);
      expect(r.isOk, isFalse);
      expect(r.error, equals(SipInkSimplifyError.empty));
    });

    test('rejects too many strokes up front', () {
      final raws = List.generate(
        SipInkConstants.maxStrokes + 1,
        (i) => SipInkRawStroke(
          width: 1,
          points: [(x: 0.0, y: i.toDouble()), (x: 1.0, y: i.toDouble())],
        ),
      );
      final r = SipInkSimplifier.simplify(rawStrokes: raws, canvasSize: 64);
      expect(r.error, equals(SipInkSimplifyError.tooManyStrokes));
    });

    test('drops strokes that collapse to a single dedup\'d point', () {
      // A stroke where every raw point quantises to the same integer.
      final degenerate = SipInkRawStroke(
        width: 1,
        points: const [(x: 5.0, y: 5.0), (x: 5.1, y: 5.1), (x: 5.2, y: 5.0)],
      );
      final r = SipInkSimplifier.simplify(
        rawStrokes: [degenerate],
        canvasSize: 64,
      );
      expect(r.isOk, isFalse);
      expect(r.error, equals(SipInkSimplifyError.empty));
    });

    test('quantises and produces an encodable sketch for typical input', () {
      final r = SipInkSimplifier.simplify(
        rawStrokes: [_smiley(2)],
        canvasSize: 64,
      );
      expect(r.isOk, isTrue);
      final encoded = SipInkEncoder.encode(r.sketch!);
      expect(encoded.isOk, isTrue);
      expect(
        encoded.bytes!.length,
        lessThanOrEqualTo(SipInkConstants.maxPayloadBytes),
      );
    });

    test('determinism: same raw input -> same encoded bytes', () {
      final raws = [_smiley(2), _smiley(1)];
      final a = SipInkSimplifier.simplify(rawStrokes: raws, canvasSize: 64);
      final b = SipInkSimplifier.simplify(rawStrokes: raws, canvasSize: 64);
      expect(a.isOk, isTrue);
      expect(b.isOk, isTrue);
      final ea = SipInkEncoder.encode(a.sketch!).bytes!;
      final eb = SipInkEncoder.encode(b.sketch!).bytes!;
      expect(ea, equals(eb));
    });

    test('clamps points outside the canvas instead of failing', () {
      final r = SipInkSimplifier.simplify(
        rawStrokes: [
          SipInkRawStroke(
            width: 1,
            points: const [(x: -50.0, y: -50.0), (x: 200.0, y: 200.0)],
          ),
        ],
        canvasSize: 64,
      );
      expect(r.isOk, isTrue);
    });

    test('large input is still encodable after epsilon bumps', () {
      // 200-point near-diagonal — far above the 64-point cap.
      final pts = List<({double x, double y})>.generate(
        200,
        (i) => (x: i * 0.3, y: i * 0.3),
      );
      final r = SipInkSimplifier.simplify(
        rawStrokes: [SipInkRawStroke(width: 1, points: pts)],
        canvasSize: 64,
      );
      expect(r.isOk, isTrue);
      expect(
        r.sketch!.totalPointCount,
        lessThanOrEqualTo(SipInkConstants.maxTotalPoints),
      );
      final encoded = SipInkEncoder.encode(r.sketch!).bytes!;
      final decoded = SipInkDecoder.decode(encoded);
      expect(decoded.isOk, isTrue);
    });

    test('preserves first and last points', () {
      final raws = [
        SipInkRawStroke(
          width: 1,
          points: const [
            (x: 5.0, y: 5.0),
            (x: 6.0, y: 5.0),
            (x: 7.0, y: 5.0),
            (x: 12.0, y: 5.0),
            (x: 13.0, y: 5.0),
          ],
        ),
      ];
      final r = SipInkSimplifier.simplify(rawStrokes: raws, canvasSize: 64);
      expect(r.isOk, isTrue);
      final stroke = r.sketch!.strokes.first;
      expect(stroke.points.first.x, equals(5));
      expect(stroke.points.first.y, equals(5));
      expect(stroke.points.last.x, equals(13));
      expect(stroke.points.last.y, equals(5));
    });
  });
}
