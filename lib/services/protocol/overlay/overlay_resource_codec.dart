// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SPP v0.2 resource-frame codec.
///
/// Encodes and decodes the 10-byte header defined in
/// `docs/sip/OVERLAY_V0_2.md` §11.2. SPP v0.2 frames ride inside the
/// payload of an MRRP v0.2 `LINK_DATA` frame.
///
/// Wire layout:
///
/// ```
/// Offset  Size  Field
/// 0       1     type          OverlayResourceMsgType
/// 1       1     version       OverlayResourceConstants.version (0x02)
/// 2       4     resourceId    LE, assigned by sender
/// 6       2     chunkIndex    LE, per-message index
/// 8       2     chunkCount    LE, total chunks (0 where not meaningful)
/// 10..    var   payload       type-specific body
/// ```
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import 'overlay_constants.dart';
import 'overlay_types.dart';

/// A parsed SPP v0.2 resource frame.
class OverlayResourceFrame {
  /// Resource-layer message type.
  final OverlayResourceMsgType type;

  /// Wire protocol version. Always [OverlayResourceConstants.version].
  final int version;

  /// 4-byte resource identifier (offsets 2-5).
  final int resourceId;

  /// 2-byte chunk index (offsets 6-7).
  ///
  /// For CHUNK/NACK, this is the zero-based chunk number. For OFFER,
  /// ACCEPT, DECLINE, COMPLETE, etc., this is zero.
  final int chunkIndex;

  /// 2-byte total chunk count (offsets 8-9).
  ///
  /// Meaningful only when carried by OFFER, CHUNK, and COMPLETE
  /// frames. Other types write 0.
  final int chunkCount;

  /// Message-type specific body.
  final Uint8List payload;

  const OverlayResourceFrame({
    required this.type,
    this.version = OverlayResourceConstants.version,
    required this.resourceId,
    this.chunkIndex = 0,
    this.chunkCount = 0,
    required this.payload,
  });

  @override
  String toString() =>
      'OverlayResourceFrame('
      'type=${type.name}, '
      'resourceId=0x${resourceId.toRadixString(16).padLeft(8, '0')}, '
      'chunkIndex=$chunkIndex, chunkCount=$chunkCount, '
      'payloadLen=${payload.length})';
}

/// Errors raised by [OverlayResourceCodec] on malformed input.
enum OverlayResourceDecodeError {
  /// Buffer shorter than the 10-byte header.
  short,

  /// `type` byte is not a known [OverlayResourceMsgType].
  badType,

  /// `version` byte is not [OverlayResourceConstants.version].
  badVersion,

  /// Payload would exceed the unsigned chunk ceiling.
  badPayloadLen,
}

/// Decode result.
class OverlayResourceDecodeResult {
  /// Decoded frame on success.
  final OverlayResourceFrame? frame;

  /// Error kind on failure.
  final OverlayResourceDecodeError? error;

  /// Diagnostic message on failure.
  final String? message;

  const OverlayResourceDecodeResult._(this.frame, this.error, this.message);

  /// Success constructor.
  const OverlayResourceDecodeResult.ok(OverlayResourceFrame frame)
    : this._(frame, null, null);

  /// Failure constructor.
  const OverlayResourceDecodeResult.fail(
    OverlayResourceDecodeError error,
    String message,
  ) : this._(null, error, message);

  /// Convenience getter.
  bool get isOk => frame != null;
}

/// Encode / decode SPP v0.2 resource frames.
abstract final class OverlayResourceCodec {
  /// Quick sniff: does [data] look like an SPP v0.2 frame?
  ///
  /// Validates header length, version byte, and type code. Does not
  /// validate payload length.
  static bool isResourceFrame(Uint8List data) {
    if (data.length < OverlayResourceConstants.headerLen) return false;
    if (data[1] != OverlayResourceConstants.version) return false;
    if (OverlayResourceMsgType.fromCode(data[0]) == null) return false;
    return true;
  }

  /// Encode a [OverlayResourceFrame] into wire bytes.
  static Uint8List? encode(OverlayResourceFrame frame) {
    if (frame.version != OverlayResourceConstants.version) {
      AppLogging.overlay(
        'resource encode REJECTED: version=${frame.version} != '
        '${OverlayResourceConstants.version}',
      );
      return null;
    }
    if (!_u32Ok(frame.resourceId) ||
        !_u16Ok(frame.chunkIndex) ||
        !_u16Ok(frame.chunkCount)) {
      AppLogging.overlay(
        'resource encode REJECTED: integer field out of range',
      );
      return null;
    }
    if (frame.payload.length >
        OverlayResourceConstants.chunkPayloadCeilUnsigned) {
      AppLogging.overlay(
        'resource encode REJECTED: payload=${frame.payload.length} '
        'exceeds unsigned ceiling '
        '${OverlayResourceConstants.chunkPayloadCeilUnsigned}',
      );
      return null;
    }

    final total = OverlayResourceConstants.headerLen + frame.payload.length;
    final out = ByteData(total);
    var o = 0;
    out.setUint8(o++, frame.type.code);
    out.setUint8(o++, frame.version);
    out.setUint32(o, frame.resourceId, Endian.little);
    o += 4;
    out.setUint16(o, frame.chunkIndex, Endian.little);
    o += 2;
    out.setUint16(o, frame.chunkCount, Endian.little);
    o += 2;

    final buffer = out.buffer.asUint8List();
    if (frame.payload.isNotEmpty) {
      buffer.setRange(OverlayResourceConstants.headerLen, total, frame.payload);
    }
    return buffer;
  }

  /// Decode wire bytes into a frame, or return a typed error.
  static OverlayResourceDecodeResult decode(Uint8List data) {
    if (data.length < OverlayResourceConstants.headerLen) {
      return OverlayResourceDecodeResult.fail(
        OverlayResourceDecodeError.short,
        'need >= ${OverlayResourceConstants.headerLen} bytes, got '
        '${data.length}',
      );
    }
    final type = OverlayResourceMsgType.fromCode(data[0]);
    if (type == null) {
      return OverlayResourceDecodeResult.fail(
        OverlayResourceDecodeError.badType,
        'type=0x${data[0].toRadixString(16)} unknown',
      );
    }
    final version = data[1];
    if (version != OverlayResourceConstants.version) {
      return OverlayResourceDecodeResult.fail(
        OverlayResourceDecodeError.badVersion,
        'version=$version != ${OverlayResourceConstants.version}',
      );
    }
    final view = ByteData.view(data.buffer, data.offsetInBytes, data.length);
    final resourceId = view.getUint32(2, Endian.little);
    final chunkIndex = view.getUint16(6, Endian.little);
    final chunkCount = view.getUint16(8, Endian.little);

    final payloadLen = data.length - OverlayResourceConstants.headerLen;
    if (payloadLen > OverlayResourceConstants.chunkPayloadCeilUnsigned) {
      return OverlayResourceDecodeResult.fail(
        OverlayResourceDecodeError.badPayloadLen,
        'payloadLen=$payloadLen exceeds unsigned ceiling '
        '${OverlayResourceConstants.chunkPayloadCeilUnsigned}',
      );
    }
    final payload = payloadLen == 0
        ? Uint8List(0)
        : Uint8List.fromList(
            data.sublist(OverlayResourceConstants.headerLen, data.length),
          );

    return OverlayResourceDecodeResult.ok(
      OverlayResourceFrame(
        type: type,
        version: version,
        resourceId: resourceId,
        chunkIndex: chunkIndex,
        chunkCount: chunkCount,
        payload: payload,
      ),
    );
  }

  static bool _u16Ok(int v) => v >= 0 && v <= 0xFFFF;
  static bool _u32Ok(int v) => v >= 0 && v <= 0xFFFFFFFF;
}
