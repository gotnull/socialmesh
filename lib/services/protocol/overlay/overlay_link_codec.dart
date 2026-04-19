// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP v0.2 link-frame codec.
///
/// Encodes and decodes the 28-byte header defined in
/// `docs/sip/OVERLAY_V0_2.md` §10.2. The first 20 bytes are byte-
/// compatible with MRRP v0.1 (`mrrp_frame.dart` / `mrrp_codec.dart`).
/// The final 8 bytes carry the fixed `linkId / seq / ackHi` tuple.
///
/// This file is pure codec logic: no IO, no provider access, no
/// singleton state. It is the foundation for phase P0 and is covered
/// by byte-accurate golden vectors under `test/services/protocol/overlay/`.
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import 'overlay_constants.dart';
import 'overlay_types.dart';

/// A parsed MRRP v0.2 link frame.
///
/// All integer fields are unsigned. All multi-byte integers are encoded
/// little-endian on the wire. Payload bytes are the message-type
/// specific body (for `LINK_DATA`, this is an SPP v0.2 frame).
class OverlayLinkFrame {
  /// MRRP major version. Always `0` in v0.2.
  final int versionMajor;

  /// MRRP minor version. Always `2` in v0.2.
  final int versionMinor;

  /// Link-layer message type. See [OverlayLinkMsgType].
  final OverlayLinkMsgType msgType;

  /// Flags bitfield. Must include [OverlayLinkFlags.linkFrame].
  final int flags;

  /// Total header length in bytes. Fixed at 28 in v0.2.
  final int headerLen;

  /// MRRP `request_id` (offsets 8-11). Used by control flows such as
  /// `LINK_OPEN` ↔ `LINK_OPEN_OK` for correlation. `0` when unused.
  final int requestId;

  /// MRRP `service_id` (offsets 12-15). `0` for pure link frames;
  /// non-zero if the link frame rides alongside an MRRP service.
  final int serviceId;

  /// MRRP `action_id` (offsets 16-17). Carries v0.2 action subcodes.
  final int actionId;

  /// Length of the payload body in bytes (offsets 18-19).
  final int payloadLen;

  /// 4-byte link identifier (offsets 20-23).
  final int linkId;

  /// Sender monotonic sequence number (offsets 24-25).
  final int seq;

  /// Highest cumulative sequence number the sender has acknowledged
  /// from its counterpart (offsets 26-27).
  final int ackHi;

  /// Message-type-specific payload bytes.
  final Uint8List payload;

  const OverlayLinkFrame({
    this.versionMajor = OverlayLinkConstants.versionMajor,
    this.versionMinor = OverlayLinkConstants.versionMinor,
    required this.msgType,
    required this.flags,
    this.headerLen = OverlayLinkConstants.headerLen,
    required this.requestId,
    required this.serviceId,
    required this.actionId,
    required this.payloadLen,
    required this.linkId,
    required this.seq,
    required this.ackHi,
    required this.payload,
  });

  @override
  String toString() =>
      'OverlayLinkFrame('
      'msg=${msgType.name}, '
      'linkId=0x${linkId.toRadixString(16).padLeft(8, '0')}, '
      'seq=$seq, ackHi=$ackHi, '
      'payloadLen=$payloadLen)';
}

/// Errors raised by [OverlayLinkCodec] on malformed input.
enum OverlayLinkDecodeError {
  /// Input shorter than the 28-byte header.
  short,

  /// Magic bytes at offsets 0-1 do not match `0x4D 0x52` ("MR").
  badMagic,

  /// `version_major` is not 0 or `version_minor` is not 2.
  badVersion,

  /// `msg_type` is not in the v0.2 link range (0x20..0x27).
  badMsgType,

  /// Reserved flag bits are non-zero, or the `linkFrame` bit is clear.
  badFlags,

  /// `header_len` is not 28.
  badHeaderLen,

  /// `payload_len` disagrees with the buffer length, or overflows the
  /// v0.2 payload ceiling.
  badPayloadLen,
}

/// Result of a decode attempt.
class OverlayLinkDecodeResult {
  /// The decoded frame on success.
  final OverlayLinkFrame? frame;

  /// The error kind on failure.
  final OverlayLinkDecodeError? error;

  /// A human-readable diagnostic message on failure.
  final String? message;

  const OverlayLinkDecodeResult._(this.frame, this.error, this.message);

  /// Success constructor.
  const OverlayLinkDecodeResult.ok(OverlayLinkFrame frame)
    : this._(frame, null, null);

  /// Failure constructor.
  const OverlayLinkDecodeResult.fail(
    OverlayLinkDecodeError error,
    String message,
  ) : this._(null, error, message);

  /// Convenience getter.
  bool get isOk => frame != null;
}

/// Encode / decode MRRP v0.2 link frames.
abstract final class OverlayLinkCodec {
  /// MRRP magic byte 0 ('M').
  static const int magic0 = 0x4D;

  /// MRRP magic byte 1 ('R').
  static const int magic1 = 0x52;

  /// Quick sniff: does [data] look like an MRRP v0.2 link frame?
  ///
  /// Checks magic bytes, version, msg_type range, and `linkFrame` flag.
  /// Does not validate lengths. Safe on arbitrarily short input.
  static bool isLinkFrame(Uint8List data) {
    if (data.length < OverlayLinkConstants.headerLen) return false;
    if (data[0] != magic0 || data[1] != magic1) return false;
    if (data[2] != OverlayLinkConstants.versionMajor) return false;
    if (data[3] != OverlayLinkConstants.versionMinor) return false;
    if (OverlayLinkMsgType.fromCode(data[4]) == null) return false;
    if ((data[5] & OverlayLinkFlags.linkFrame) == 0) return false;
    return true;
  }

  /// Encode a [OverlayLinkFrame] into wire bytes.
  ///
  /// Returns null and logs at the `overlay` feature scope if the frame
  /// exceeds [OverlayLinkConstants.payloadCeilUnsigned]. Callers that
  /// intentionally plan to carry the frame inside a signed SIP wrapper
  /// must validate against [OverlayLinkConstants.payloadCeilSigned]
  /// themselves before calling encode; the codec uses the looser
  /// ceiling so unit tests can exercise the full unsigned range.
  static Uint8List? encode(OverlayLinkFrame frame) {
    if (frame.versionMajor != OverlayLinkConstants.versionMajor ||
        frame.versionMinor != OverlayLinkConstants.versionMinor) {
      AppLogging.overlay(
        'encode REJECTED: version ${frame.versionMajor}.${frame.versionMinor} '
        'is not v0.2',
      );
      return null;
    }
    if (frame.headerLen != OverlayLinkConstants.headerLen) {
      AppLogging.overlay(
        'encode REJECTED: headerLen=${frame.headerLen} != '
        '${OverlayLinkConstants.headerLen}',
      );
      return null;
    }
    if ((frame.flags & OverlayLinkFlags.reservedMask) != 0) {
      AppLogging.overlay(
        'encode REJECTED: reserved flag bits set flags=0x'
        '${frame.flags.toRadixString(16)}',
      );
      return null;
    }
    if ((frame.flags & OverlayLinkFlags.linkFrame) == 0) {
      AppLogging.overlay(
        'encode REJECTED: linkFrame flag MUST be set on v0.2 frames',
      );
      return null;
    }
    if (frame.payload.length != frame.payloadLen) {
      AppLogging.overlay(
        'encode REJECTED: payload.length=${frame.payload.length} != '
        'payloadLen=${frame.payloadLen}',
      );
      return null;
    }
    if (frame.payloadLen > OverlayLinkConstants.payloadCeilUnsigned) {
      AppLogging.overlay(
        'encode REJECTED: payloadLen=${frame.payloadLen} exceeds unsigned '
        'ceiling ${OverlayLinkConstants.payloadCeilUnsigned}',
      );
      return null;
    }
    if (!_u32Ok(frame.requestId) ||
        !_u32Ok(frame.serviceId) ||
        !_u16Ok(frame.actionId) ||
        !_u16Ok(frame.payloadLen) ||
        !_u32Ok(frame.linkId) ||
        !_u16Ok(frame.seq) ||
        !_u16Ok(frame.ackHi)) {
      AppLogging.overlay('encode REJECTED: integer field out of range');
      return null;
    }

    final total = frame.headerLen + frame.payloadLen;
    final out = ByteData(total);
    var o = 0;

    out.setUint8(o++, magic0);
    out.setUint8(o++, magic1);
    out.setUint8(o++, frame.versionMajor);
    out.setUint8(o++, frame.versionMinor);
    out.setUint8(o++, frame.msgType.code);
    out.setUint8(o++, frame.flags);
    out.setUint16(o, frame.headerLen, Endian.little);
    o += 2;
    out.setUint32(o, frame.requestId, Endian.little);
    o += 4;
    out.setUint32(o, frame.serviceId, Endian.little);
    o += 4;
    out.setUint16(o, frame.actionId, Endian.little);
    o += 2;
    out.setUint16(o, frame.payloadLen, Endian.little);
    o += 2;
    out.setUint32(o, frame.linkId, Endian.little);
    o += 4;
    out.setUint16(o, frame.seq, Endian.little);
    o += 2;
    out.setUint16(o, frame.ackHi, Endian.little);
    o += 2;

    if (frame.payloadLen > 0) {
      final buffer = out.buffer.asUint8List();
      buffer.setRange(
        OverlayLinkConstants.headerLen,
        OverlayLinkConstants.headerLen + frame.payloadLen,
        frame.payload,
      );
    }

    return out.buffer.asUint8List();
  }

  /// Decode wire bytes into a frame, or return a typed error.
  static OverlayLinkDecodeResult decode(Uint8List data) {
    if (data.length < OverlayLinkConstants.headerLen) {
      return OverlayLinkDecodeResult.fail(
        OverlayLinkDecodeError.short,
        'need >= ${OverlayLinkConstants.headerLen} bytes, got ${data.length}',
      );
    }
    if (data[0] != magic0 || data[1] != magic1) {
      return OverlayLinkDecodeResult.fail(
        OverlayLinkDecodeError.badMagic,
        'magic=0x${data[0].toRadixString(16)} '
        '0x${data[1].toRadixString(16)}',
      );
    }
    final versionMajor = data[2];
    final versionMinor = data[3];
    if (versionMajor != OverlayLinkConstants.versionMajor ||
        versionMinor != OverlayLinkConstants.versionMinor) {
      return OverlayLinkDecodeResult.fail(
        OverlayLinkDecodeError.badVersion,
        'version $versionMajor.$versionMinor is not v0.2',
      );
    }
    final msgType = OverlayLinkMsgType.fromCode(data[4]);
    if (msgType == null) {
      return OverlayLinkDecodeResult.fail(
        OverlayLinkDecodeError.badMsgType,
        'msg_type=0x${data[4].toRadixString(16)} outside v0.2 range',
      );
    }
    final flags = data[5];
    if ((flags & OverlayLinkFlags.reservedMask) != 0) {
      return OverlayLinkDecodeResult.fail(
        OverlayLinkDecodeError.badFlags,
        'reserved bits set flags=0x${flags.toRadixString(16)}',
      );
    }
    if ((flags & OverlayLinkFlags.linkFrame) == 0) {
      return OverlayLinkDecodeResult.fail(
        OverlayLinkDecodeError.badFlags,
        'linkFrame bit must be 1 for v0.2',
      );
    }
    final view = ByteData.view(data.buffer, data.offsetInBytes, data.length);
    final headerLen = view.getUint16(6, Endian.little);
    if (headerLen != OverlayLinkConstants.headerLen) {
      return OverlayLinkDecodeResult.fail(
        OverlayLinkDecodeError.badHeaderLen,
        'header_len=$headerLen != ${OverlayLinkConstants.headerLen}',
      );
    }
    final requestId = view.getUint32(8, Endian.little);
    final serviceId = view.getUint32(12, Endian.little);
    final actionId = view.getUint16(16, Endian.little);
    final payloadLen = view.getUint16(18, Endian.little);
    if (payloadLen > OverlayLinkConstants.payloadCeilUnsigned) {
      return OverlayLinkDecodeResult.fail(
        OverlayLinkDecodeError.badPayloadLen,
        'payloadLen=$payloadLen exceeds unsigned ceiling '
        '${OverlayLinkConstants.payloadCeilUnsigned}',
      );
    }
    if (data.length < headerLen + payloadLen) {
      return OverlayLinkDecodeResult.fail(
        OverlayLinkDecodeError.badPayloadLen,
        'buffer length ${data.length} < headerLen+payloadLen '
        '=${headerLen + payloadLen}',
      );
    }
    final linkId = view.getUint32(20, Endian.little);
    final seq = view.getUint16(24, Endian.little);
    final ackHi = view.getUint16(26, Endian.little);

    final payload = Uint8List.fromList(
      data.sublist(headerLen, headerLen + payloadLen),
    );

    return OverlayLinkDecodeResult.ok(
      OverlayLinkFrame(
        versionMajor: versionMajor,
        versionMinor: versionMinor,
        msgType: msgType,
        flags: flags,
        headerLen: headerLen,
        requestId: requestId,
        serviceId: serviceId,
        actionId: actionId,
        payloadLen: payloadLen,
        linkId: linkId,
        seq: seq,
        ackHi: ackHi,
        payload: payload,
      ),
    );
  }

  static bool _u16Ok(int v) => v >= 0 && v <= 0xFFFF;
  static bool _u32Ok(int v) => v >= 0 && v <= 0xFFFFFFFF;
}
