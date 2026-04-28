// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP Ink v1 encoder: structured sketch -> binary payload.
///
/// Output is deterministic: the same [SipInkSketch] always produces the
/// same byte sequence. This is required for the wire-vector tests in
/// `test/services/protocol/sip/sip_ink_encoder_test.dart`.
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import 'sip_ink_constants.dart';
import 'sip_ink_payload.dart';

/// Reasons an encode can fail. Caller should treat these as terminal —
/// the simplifier is what knows how to retry within a tighter budget.
enum SipInkEncodeError {
  empty,
  tooManyStrokes,
  tooManyPoints,
  strokeTooShort,
  invalidWidth,
  invalidCanvas,
  pointOutOfBounds,
  deltaOverflow,
  payloadTooLarge,
}

/// Result of [SipInkEncoder.encode].
class SipInkEncodeResult {
  final Uint8List? bytes;
  final SipInkEncodeError? error;

  const SipInkEncodeResult._({this.bytes, this.error});

  factory SipInkEncodeResult.ok(Uint8List bytes) =>
      SipInkEncodeResult._(bytes: bytes);

  factory SipInkEncodeResult.fail(SipInkEncodeError error) =>
      SipInkEncodeResult._(error: error);

  bool get isOk => bytes != null;
}

/// Encoder for SIP Ink v1 sketches. See [SipInkConstants] for layout.
abstract final class SipInkEncoder {
  /// Encode [sketch] to a binary payload.
  ///
  /// Returns a result holding the bytes on success, or a typed error.
  /// Validation is strict: any stroke or point that violates the spec
  /// causes a fail rather than silent truncation.
  static SipInkEncodeResult encode(SipInkSketch sketch) {
    final strokes = sketch.strokes;
    if (strokes.isEmpty) {
      return SipInkEncodeResult.fail(SipInkEncodeError.empty);
    }
    if (strokes.length > SipInkConstants.maxStrokes) {
      return SipInkEncodeResult.fail(SipInkEncodeError.tooManyStrokes);
    }
    if (sketch.canvasSize != SipInkConstants.canvas64 &&
        sketch.canvasSize != SipInkConstants.canvas128) {
      return SipInkEncodeResult.fail(SipInkEncodeError.invalidCanvas);
    }

    var totalPoints = 0;
    for (final stroke in strokes) {
      if (stroke.points.length < SipInkConstants.minPointsPerStroke) {
        return SipInkEncodeResult.fail(SipInkEncodeError.strokeTooShort);
      }
      if (stroke.width < SipInkConstants.minStrokeWidth ||
          stroke.width > SipInkConstants.maxStrokeWidth) {
        return SipInkEncodeResult.fail(SipInkEncodeError.invalidWidth);
      }
      for (final p in stroke.points) {
        if (p.x < 0 ||
            p.x >= sketch.canvasSize ||
            p.y < 0 ||
            p.y >= sketch.canvasSize) {
          return SipInkEncodeResult.fail(SipInkEncodeError.pointOutOfBounds);
        }
      }
      totalPoints += stroke.points.length;
    }
    if (totalPoints > SipInkConstants.maxTotalPoints) {
      return SipInkEncodeResult.fail(SipInkEncodeError.tooManyPoints);
    }

    var size = SipInkConstants.globalHeaderBytes;
    for (final stroke in strokes) {
      size += SipInkConstants.strokeHeaderBytes;
      size += stroke.points.length - 1;
    }
    if (size > SipInkConstants.maxPayloadBytes) {
      return SipInkEncodeResult.fail(SipInkEncodeError.payloadTooLarge);
    }

    final out = Uint8List(size);
    var off = 0;
    out[off++] = SipInkConstants.typeAndVersionV1;
    out[off++] = sketch.canvasSize == SipInkConstants.canvas128
        ? SipInkConstants.flagCanvas128
        : 0;
    out[off++] = strokes.length;
    out[off++] = totalPoints;

    for (final stroke in strokes) {
      out[off++] = stroke.width & 0x0F;
      out[off++] = stroke.points.length;
      out[off++] = stroke.points.first.x;
      out[off++] = stroke.points.first.y;
      var prev = stroke.points.first;
      for (var i = 1; i < stroke.points.length; i++) {
        final p = stroke.points[i];
        final dx = p.x - prev.x;
        final dy = p.y - prev.y;
        if (dx < SipInkConstants.deltaMin ||
            dx > SipInkConstants.deltaMax ||
            dy < SipInkConstants.deltaMin ||
            dy > SipInkConstants.deltaMax) {
          return SipInkEncodeResult.fail(SipInkEncodeError.deltaOverflow);
        }
        out[off++] = ((dx + 8) << 4) | (dy + 8);
        prev = p;
      }
    }

    AppLogging.sipInk(
      'encode_ok strokes=${strokes.length} points=$totalPoints '
      'canvas=${sketch.canvasSize} bytes=$size',
    );
    return SipInkEncodeResult.ok(out);
  }
}
