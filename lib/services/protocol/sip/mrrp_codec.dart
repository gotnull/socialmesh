// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP frame encoder/decoder with TLV parsing and strict bounds checking.
///
/// Follows the wire format defined in docs/sip/MRRP_V0_1.md.
/// Frames are carried inside SIP payloads and bounded by
/// [SipConstants.sipMaxPayload] (215 bytes).
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import 'mrrp_constants.dart';
import 'mrrp_frame.dart';
import 'mrrp_types.dart';
import 'sip_constants.dart';

/// MRRP frame encoder/decoder.
///
/// All methods are static. Encoding produces a [Uint8List] suitable for
/// embedding in a SIP frame payload. Decoding validates magic bytes,
/// version, header length, payload length, and total size bounds.
abstract final class MrrpCodec {
  /// Check whether [data] starts with MRRP magic bytes (0x4D 0x52).
  static bool isMrrpPayload(Uint8List data) {
    if (data.length < 2) return false;
    return data[0] == MrrpConstants.mrrpMagicByte0 &&
        data[1] == MrrpConstants.mrrpMagicByte1;
  }

  /// Encode an [MrrpFrame] to wire bytes.
  ///
  /// Returns null if the encoded frame would exceed [SipConstants.sipMaxPayload].
  static Uint8List? encode(MrrpFrame frame) {
    // Calculate TLV extension size
    var extSize = 0;
    for (final ext in frame.headerExtensions) {
      extSize += 2 + ext.value.length; // type(1) + len(1) + value
    }

    final headerLen = MrrpConstants.mrrpHeaderMin + extSize;
    final totalSize = headerLen + frame.payload.length;

    if (totalSize > SipConstants.sipMaxPayload) {
      AppLogging.mrrp(
        'MRRP_CODEC: encode rejected, total=$totalSize > ${SipConstants.sipMaxPayload}', // lint-allow: hardcoded-string
      );
      return null;
    }

    final buffer = Uint8List(totalSize);
    final bd = ByteData.sublistView(buffer);

    // Magic bytes
    buffer[0] = MrrpConstants.mrrpMagicByte0;
    buffer[1] = MrrpConstants.mrrpMagicByte1;

    // Version
    buffer[2] = frame.versionMajor;
    buffer[3] = frame.versionMinor;

    // Message type
    buffer[4] = frame.msgType.code;

    // Flags
    buffer[5] = frame.flags;

    // Header length (LE uint16)
    bd.setUint16(6, headerLen, Endian.little);

    // Request ID (LE uint32)
    bd.setUint32(8, frame.requestId, Endian.little);

    // Service ID (LE uint32)
    bd.setUint32(12, frame.serviceId, Endian.little);

    // Action ID (LE uint16)
    bd.setUint16(16, frame.actionId, Endian.little);

    // Payload length (LE uint16)
    bd.setUint16(18, frame.payload.length, Endian.little);

    // TLV header extensions
    var offset = MrrpConstants.mrrpHeaderMin;
    for (final ext in frame.headerExtensions) {
      buffer[offset] = ext.type;
      buffer[offset + 1] = ext.value.length;
      buffer.setRange(offset + 2, offset + 2 + ext.value.length, ext.value);
      offset += 2 + ext.value.length;
    }

    // Payload
    buffer.setRange(headerLen, totalSize, frame.payload);

    AppLogging.mrrp(
      'MRRP_CODEC: encode msg_type=0x${frame.msgType.code.toRadixString(16)} ' // lint-allow: hardcoded-string
      'service=0x${frame.serviceId.toRadixString(16).padLeft(8, '0')} '
      'action=0x${frame.actionId.toRadixString(16).padLeft(4, '0')} '
      'payload=${frame.payload.length}B total=${totalSize}B',
    );

    return buffer;
  }

  /// Decode wire bytes to an [MrrpFrame].
  ///
  /// Returns null if the data is invalid (wrong magic, insufficient length,
  /// version mismatch, or bounds violation).
  static MrrpFrame? decode(Uint8List data) {
    // Minimum frame size check
    if (data.length < MrrpConstants.mrrpHeaderMin) {
      AppLogging.mrrp(
        'MRRP_CODEC: decode rejected, len=${data.length} < ${MrrpConstants.mrrpHeaderMin}', // lint-allow: hardcoded-string
      );
      return null;
    }

    // Magic byte validation
    if (data[0] != MrrpConstants.mrrpMagicByte0 ||
        data[1] != MrrpConstants.mrrpMagicByte1) {
      return null;
    }

    final bd = ByteData.sublistView(data);

    // Version check: drop if major > 0
    final versionMajor = data[2];
    if (versionMajor > MrrpConstants.mrrpVersionMajor) {
      AppLogging.mrrp(
        'MRRP_CODEC: unsupported version_major=$versionMajor', // lint-allow: hardcoded-string
      );
      return null;
    }

    final versionMinor = data[3];

    // Message type lookup
    final msgTypeCode = data[4];
    final msgType = MrrpMessageType.fromCode(msgTypeCode);
    if (msgType == null) {
      AppLogging.mrrp(
        'MRRP_CODEC: unknown msg_type=0x${msgTypeCode.toRadixString(16)}', // lint-allow: hardcoded-string
      );
      return null;
    }

    final flags = data[5];

    // Header length (LE uint16)
    final headerLen = bd.getUint16(6, Endian.little);
    if (headerLen < MrrpConstants.mrrpHeaderMin) {
      AppLogging.mrrp(
        'MRRP_CODEC: header_len=$headerLen < ${MrrpConstants.mrrpHeaderMin}', // lint-allow: hardcoded-string
      );
      return null;
    }
    if (headerLen > data.length) {
      AppLogging.mrrp(
        'MRRP_CODEC: header_len=$headerLen > data.length=${data.length}', // lint-allow: hardcoded-string
      );
      return null;
    }

    // Request ID (LE uint32)
    final requestId = bd.getUint32(8, Endian.little);

    // Service ID (LE uint32)
    final serviceId = bd.getUint32(12, Endian.little);

    // Action ID (LE uint16)
    final actionId = bd.getUint16(16, Endian.little);

    // Payload length (LE uint16)
    final payloadLen = bd.getUint16(18, Endian.little);

    // Total frame size validation
    final totalSize = headerLen + payloadLen;
    if (totalSize > data.length) {
      AppLogging.mrrp(
        'MRRP_CODEC: total=$totalSize > data.length=${data.length}', // lint-allow: hardcoded-string
      );
      return null;
    }
    if (totalSize > SipConstants.sipMaxPayload) {
      AppLogging.mrrp(
        'MRRP_CODEC: total=$totalSize > SIP_MAX_PAYLOAD=${SipConstants.sipMaxPayload}', // lint-allow: hardcoded-string
      );
      return null;
    }

    // Parse TLV header extensions
    final headerExtensions = <MrrpTlvEntry>[];
    var offset = MrrpConstants.mrrpHeaderMin;
    while (offset + 2 <= headerLen) {
      final tlvType = data[offset];
      final tlvLen = data[offset + 1];
      if (offset + 2 + tlvLen > headerLen) break;
      final tlvValue = Uint8List.sublistView(
        data,
        offset + 2,
        offset + 2 + tlvLen,
      );
      headerExtensions.add(MrrpTlvEntry(type: tlvType, value: tlvValue));
      offset += 2 + tlvLen;
    }

    // Extract payload
    final payload = Uint8List.sublistView(
      data,
      headerLen,
      headerLen + payloadLen,
    );

    AppLogging.mrrp(
      'MRRP_CODEC: decode ${data.length}B -> msg_type=0x${msgTypeCode.toRadixString(16)} ' // lint-allow: hardcoded-string
      'service=0x${serviceId.toRadixString(16).padLeft(8, '0')} '
      'action=0x${actionId.toRadixString(16).padLeft(4, '0')} '
      'payload=${payloadLen}B',
    );

    return MrrpFrame(
      magic0: data[0],
      magic1: data[1],
      versionMajor: versionMajor,
      versionMinor: versionMinor,
      msgType: msgType,
      flags: flags,
      headerLen: headerLen,
      requestId: requestId,
      serviceId: serviceId,
      actionId: actionId,
      payloadLen: payloadLen,
      headerExtensions: headerExtensions,
      payload: payload,
    );
  }
}
