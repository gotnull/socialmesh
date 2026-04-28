// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP Ink v1 decoder: binary payload -> structured sketch.
///
/// The decoder is strict-but-safe: every malformed input returns a
/// typed error rather than throwing, so the rendering layer can fall
/// back to "Unsupported sketch" without ever crashing.
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import 'sip_ink_constants.dart';
import 'sip_ink_payload.dart';

/// Why a decode failed.
enum SipInkDecodeError {
  underflow,
  unsupportedVersion,
  unsupportedType,
  reservedFlagsSet,
  tooManyStrokes,
  tooManyPoints,
  strokeTooShort,
  invalidWidth,
  pointOutOfBounds,
  pointCountMismatch,
}

/// Result of [SipInkDecoder.decode].
class SipInkDecodeResult {
  final SipInkSketch? sketch;
  final SipInkDecodeError? error;

  const SipInkDecodeResult._({this.sketch, this.error});

  factory SipInkDecodeResult.ok(SipInkSketch s) =>
      SipInkDecodeResult._(sketch: s);

  factory SipInkDecodeResult.fail(SipInkDecodeError e) =>
      SipInkDecodeResult._(error: e);

  bool get isOk => sketch != null;
}

/// Decoder for SIP Ink v1 payloads. Layout is defined in
/// [SipInkConstants].
abstract final class SipInkDecoder {
  /// Decode [payload] to a structured sketch. Never throws.
  static SipInkDecodeResult decode(Uint8List payload) {
    if (payload.length < SipInkConstants.globalHeaderBytes) {
      AppLogging.sipInk('decode_failed reason=underflow len=${payload.length}');
      return SipInkDecodeResult.fail(SipInkDecodeError.underflow);
    }

    final typeAndVer = payload[0];
    final type = (typeAndVer >> 4) & 0x0F;
    final version = typeAndVer & 0x0F;
    if (type != SipInkConstants.typeCode) {
      AppLogging.sipInk(
        'decode_failed reason=unsupported_type type=0x${type.toRadixString(16)}',
      );
      return SipInkDecodeResult.fail(SipInkDecodeError.unsupportedType);
    }
    if (version != SipInkConstants.versionV1) {
      AppLogging.sipInk(
        'decode_failed reason=unsupported_version '
        'version=0x${version.toRadixString(16)}',
      );
      return SipInkDecodeResult.fail(SipInkDecodeError.unsupportedVersion);
    }

    final flags = payload[1];
    if ((flags & SipInkConstants.reservedFlagMask) != 0) {
      AppLogging.sipInk(
        'decode_failed reason=reserved_flags '
        'flags=0x${flags.toRadixString(16)}',
      );
      return SipInkDecodeResult.fail(SipInkDecodeError.reservedFlagsSet);
    }
    final canvasSize = (flags & SipInkConstants.flagCanvas128) != 0
        ? SipInkConstants.canvas128
        : SipInkConstants.canvas64;

    final strokeCount = payload[2];
    final totalPointCount = payload[3];
    if (strokeCount == 0 || strokeCount > SipInkConstants.maxStrokes) {
      AppLogging.sipInk(
        'decode_failed reason=too_many_strokes count=$strokeCount',
      );
      return SipInkDecodeResult.fail(SipInkDecodeError.tooManyStrokes);
    }
    if (totalPointCount > SipInkConstants.maxTotalPoints) {
      AppLogging.sipInk(
        'decode_failed reason=too_many_points count=$totalPointCount',
      );
      return SipInkDecodeResult.fail(SipInkDecodeError.tooManyPoints);
    }

    var off = SipInkConstants.globalHeaderBytes;
    final strokes = <SipInkStroke>[];
    var seenPoints = 0;

    for (var s = 0; s < strokeCount; s++) {
      if (off + SipInkConstants.strokeHeaderBytes > payload.length) {
        AppLogging.sipInk('decode_failed reason=underflow at stroke=$s');
        return SipInkDecodeResult.fail(SipInkDecodeError.underflow);
      }
      final widthByte = payload[off++];
      final width = widthByte & 0x0F;
      if (width < SipInkConstants.minStrokeWidth ||
          width > SipInkConstants.maxStrokeWidth) {
        AppLogging.sipInk(
          'decode_failed reason=invalid_width width=$width stroke=$s',
        );
        return SipInkDecodeResult.fail(SipInkDecodeError.invalidWidth);
      }
      final pointCount = payload[off++];
      if (pointCount < SipInkConstants.minPointsPerStroke) {
        AppLogging.sipInk(
          'decode_failed reason=stroke_too_short count=$pointCount stroke=$s',
        );
        return SipInkDecodeResult.fail(SipInkDecodeError.strokeTooShort);
      }
      final firstX = payload[off++];
      final firstY = payload[off++];
      if (firstX >= canvasSize || firstY >= canvasSize) {
        AppLogging.sipInk(
          'decode_failed reason=point_out_of_bounds first=($firstX,$firstY) '
          'canvas=$canvasSize stroke=$s',
        );
        return SipInkDecodeResult.fail(SipInkDecodeError.pointOutOfBounds);
      }
      final deltaBytes = pointCount - 1;
      if (off + deltaBytes > payload.length) {
        AppLogging.sipInk(
          'decode_failed reason=underflow needed=$deltaBytes available=${payload.length - off}',
        );
        return SipInkDecodeResult.fail(SipInkDecodeError.underflow);
      }
      final points = <SipInkPoint>[SipInkPoint(firstX, firstY)];
      var x = firstX;
      var y = firstY;
      for (var i = 0; i < deltaBytes; i++) {
        final b = payload[off++];
        final dx = ((b >> 4) & 0x0F) - 8;
        final dy = (b & 0x0F) - 8;
        x += dx;
        y += dy;
        if (x < 0 || x >= canvasSize || y < 0 || y >= canvasSize) {
          AppLogging.sipInk(
            'decode_failed reason=point_out_of_bounds at=($x,$y) '
            'canvas=$canvasSize stroke=$s',
          );
          return SipInkDecodeResult.fail(SipInkDecodeError.pointOutOfBounds);
        }
        points.add(SipInkPoint(x, y));
      }
      strokes.add(SipInkStroke(width: width, points: points));
      seenPoints += pointCount;
    }

    if (seenPoints != totalPointCount) {
      AppLogging.sipInk(
        'decode_failed reason=point_count_mismatch '
        'declared=$totalPointCount actual=$seenPoints',
      );
      return SipInkDecodeResult.fail(SipInkDecodeError.pointCountMismatch);
    }

    AppLogging.sipInk(
      'decode_ok strokes=$strokeCount points=$totalPointCount '
      'canvas=$canvasSize bytes=${payload.length}',
    );
    return SipInkDecodeResult.ok(
      SipInkSketch(canvasSize: canvasSize, strokes: strokes),
    );
  }
}
