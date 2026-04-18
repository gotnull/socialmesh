// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Capability TLV block advertised via `CAP_BEACON` and `ID_CLAIM`.
///
/// See `docs/sip/OVERLAY_V0_2.md` §16.1 for the negotiation model. The
/// TLV block is an ordered sequence of entries:
///
/// ```
/// type(1) | length(1) | value(length)
/// ```
///
/// Three entry types are defined in v0.2 ([OverlayCapabilityTlvType]).
/// Peers MUST ignore unknown TLV types to keep forward compatibility
/// with future overlay revisions.
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import 'overlay_constants.dart';
import 'overlay_types.dart';

/// An assembled capability announcement.
class OverlayCapabilityBlock {
  /// Bitset of [OverlayCapabilityFeature] bits the peer supports.
  final int supportedFeatures;

  /// Peer-advertised chunk payload ceiling in bytes, or null if not
  /// advertised. Receivers MAY clamp their chunk size to this value.
  final int? maxChunkBytes;

  /// Peer-advertised resource size ceiling in bytes, or null if not
  /// advertised.
  final int? maxResourceBytes;

  /// Unknown TLV entries preserved for diagnostics (not re-emitted).
  final List<OverlayCapabilityUnknownTlv> unknown;

  const OverlayCapabilityBlock({
    required this.supportedFeatures,
    this.maxChunkBytes,
    this.maxResourceBytes,
    this.unknown = const <OverlayCapabilityUnknownTlv>[],
  });

  /// True if the peer advertises [OverlayCapabilityFeature.linkV02].
  bool get supportsLink =>
      (supportedFeatures & OverlayCapabilityFeature.linkV02) != 0;

  /// True if the peer advertises [OverlayCapabilityFeature.resourceV02].
  bool get supportsResource =>
      (supportedFeatures & OverlayCapabilityFeature.resourceV02) != 0;

  /// True if the peer advertises [OverlayCapabilityFeature.secureV03].
  bool get supportsSecure =>
      (supportedFeatures & OverlayCapabilityFeature.secureV03) != 0;

  @override
  String toString() =>
      'OverlayCapabilityBlock('
      'features=0x${supportedFeatures.toRadixString(16)}, '
      'maxChunk=$maxChunkBytes, maxResource=$maxResourceBytes, '
      'unknown=${unknown.length})';
}

/// An unknown TLV entry preserved during decode.
class OverlayCapabilityUnknownTlv {
  /// Unknown TLV type byte.
  final int type;

  /// Raw value bytes.
  final Uint8List value;

  const OverlayCapabilityUnknownTlv({required this.type, required this.value});
}

/// Errors raised by [OverlayCapabilityCodec] on malformed input.
enum OverlayCapabilityDecodeError {
  /// A TLV header straddles the end of the buffer.
  truncatedHeader,

  /// A TLV body extends past the end of the buffer.
  truncatedValue,

  /// Block total length exceeds [OverlayCapabilityConstants.maxBlockBytes].
  tooLarge,

  /// A known TLV has an unexpected value length.
  badValueLen,
}

/// Result of [OverlayCapabilityCodec.decode].
class OverlayCapabilityDecodeResult {
  /// Decoded block on success.
  final OverlayCapabilityBlock? block;

  /// Error kind on failure.
  final OverlayCapabilityDecodeError? error;

  /// Diagnostic on failure.
  final String? message;

  const OverlayCapabilityDecodeResult._(this.block, this.error, this.message);

  /// Success.
  const OverlayCapabilityDecodeResult.ok(OverlayCapabilityBlock block)
    : this._(block, null, null);

  /// Failure.
  const OverlayCapabilityDecodeResult.fail(
    OverlayCapabilityDecodeError error,
    String message,
  ) : this._(null, error, message);

  /// Convenience.
  bool get isOk => block != null;
}

/// Encode / decode overlay capability TLV blocks.
abstract final class OverlayCapabilityCodec {
  /// Encode a [OverlayCapabilityBlock] into wire bytes.
  ///
  /// Emits a stable TLV order: `supportedFeatures` (always),
  /// `maxChunkBytes` (if set), `maxResourceBytes` (if set). Unknown
  /// TLVs captured on decode are not re-emitted; callers intending to
  /// relay a TLV block they did not author must preserve original
  /// bytes instead of round-tripping through this codec.
  static Uint8List encode(OverlayCapabilityBlock block) {
    final parts = <Uint8List>[];
    parts.add(
      _tlv(
        OverlayCapabilityTlvType.supportedFeatures.code,
        _u32le(block.supportedFeatures),
      ),
    );
    if (block.maxChunkBytes != null) {
      parts.add(
        _tlv(
          OverlayCapabilityTlvType.maxChunkBytes.code,
          _u16le(block.maxChunkBytes!),
        ),
      );
    }
    if (block.maxResourceBytes != null) {
      parts.add(
        _tlv(
          OverlayCapabilityTlvType.maxResourceBytes.code,
          _u32le(block.maxResourceBytes!),
        ),
      );
    }
    final total = parts.fold<int>(0, (sum, p) => sum + p.length);
    if (total > OverlayCapabilityConstants.maxBlockBytes) {
      AppLogging.overlay(
        'capability encode WARN: block=$total bytes exceeds '
        'maxBlockBytes=${OverlayCapabilityConstants.maxBlockBytes}',
      );
    }
    final out = Uint8List(total);
    var o = 0;
    for (final p in parts) {
      out.setRange(o, o + p.length, p);
      o += p.length;
    }
    return out;
  }

  /// Decode a TLV block into a [OverlayCapabilityBlock].
  static OverlayCapabilityDecodeResult decode(Uint8List data) {
    if (data.length > OverlayCapabilityConstants.maxBlockBytes) {
      return OverlayCapabilityDecodeResult.fail(
        OverlayCapabilityDecodeError.tooLarge,
        'block length ${data.length} exceeds '
        '${OverlayCapabilityConstants.maxBlockBytes}',
      );
    }
    var supportedFeatures = 0;
    int? maxChunkBytes;
    int? maxResourceBytes;
    final unknown = <OverlayCapabilityUnknownTlv>[];

    var o = 0;
    while (o < data.length) {
      if (data.length - o < OverlayCapabilityConstants.tlvHeaderBytes) {
        return OverlayCapabilityDecodeResult.fail(
          OverlayCapabilityDecodeError.truncatedHeader,
          'truncated TLV header at offset $o',
        );
      }
      final type = data[o];
      final len = data[o + 1];
      o += OverlayCapabilityConstants.tlvHeaderBytes;
      if (data.length - o < len) {
        return OverlayCapabilityDecodeResult.fail(
          OverlayCapabilityDecodeError.truncatedValue,
          'TLV type=0x${type.toRadixString(16)} len=$len truncated',
        );
      }
      final value = Uint8List.fromList(data.sublist(o, o + len));
      o += len;

      final known = OverlayCapabilityTlvType.fromCode(type);
      if (known == null) {
        unknown.add(OverlayCapabilityUnknownTlv(type: type, value: value));
        continue;
      }
      switch (known) {
        case OverlayCapabilityTlvType.supportedFeatures:
          if (value.length !=
              OverlayCapabilityConstants.supportedFeaturesBytes) {
            return OverlayCapabilityDecodeResult.fail(
              OverlayCapabilityDecodeError.badValueLen,
              'supportedFeatures len=${value.length} expected '
              '${OverlayCapabilityConstants.supportedFeaturesBytes}',
            );
          }
          supportedFeatures = ByteData.view(
            value.buffer,
            value.offsetInBytes,
            value.length,
          ).getUint32(0, Endian.little);
        case OverlayCapabilityTlvType.maxChunkBytes:
          if (value.length != OverlayCapabilityConstants.maxChunkBytesBytes) {
            return OverlayCapabilityDecodeResult.fail(
              OverlayCapabilityDecodeError.badValueLen,
              'maxChunkBytes len=${value.length} expected '
              '${OverlayCapabilityConstants.maxChunkBytesBytes}',
            );
          }
          maxChunkBytes = ByteData.view(
            value.buffer,
            value.offsetInBytes,
            value.length,
          ).getUint16(0, Endian.little);
        case OverlayCapabilityTlvType.maxResourceBytes:
          if (value.length !=
              OverlayCapabilityConstants.maxResourceBytesBytes) {
            return OverlayCapabilityDecodeResult.fail(
              OverlayCapabilityDecodeError.badValueLen,
              'maxResourceBytes len=${value.length} expected '
              '${OverlayCapabilityConstants.maxResourceBytesBytes}',
            );
          }
          maxResourceBytes = ByteData.view(
            value.buffer,
            value.offsetInBytes,
            value.length,
          ).getUint32(0, Endian.little);
      }
    }

    return OverlayCapabilityDecodeResult.ok(
      OverlayCapabilityBlock(
        supportedFeatures: supportedFeatures,
        maxChunkBytes: maxChunkBytes,
        maxResourceBytes: maxResourceBytes,
        unknown: List.unmodifiable(unknown),
      ),
    );
  }

  static Uint8List _tlv(int type, Uint8List value) {
    final out = Uint8List(
      OverlayCapabilityConstants.tlvHeaderBytes + value.length,
    );
    out[0] = type;
    out[1] = value.length;
    out.setRange(OverlayCapabilityConstants.tlvHeaderBytes, out.length, value);
    return out;
  }

  static Uint8List _u16le(int v) {
    final bd = ByteData(2)..setUint16(0, v, Endian.little);
    return bd.buffer.asUint8List();
  }

  static Uint8List _u32le(int v) {
    final bd = ByteData(4)..setUint32(0, v, Endian.little);
    return bd.buffer.asUint8List();
  }
}
