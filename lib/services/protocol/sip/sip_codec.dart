// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP frame encoder/decoder with TLV parser and bounds checking.
///
/// [SipCodec] provides the core encode/decode pipeline for SIP protocol
/// frames. All validation (magic bytes, header length, payload length,
/// MTU limits, version negotiation) happens here.
library;

import 'dart:math';
import 'dart:typed_data';

import '../../../core/logging.dart';
import 'sip_constants.dart';
import 'sip_frame.dart';
import 'sip_types.dart';

/// Encode and decode SIP protocol frames.
abstract final class SipCodec {
  static final Random _secureRandom = Random.secure();

  /// Check whether a PRIVATE_APP payload starts with the SIP magic bytes.
  static bool isSipPayload(Uint8List data) {
    return data.length >= 2 &&
        data[0] == SipConstants.sipMagicByte0 &&
        data[1] == SipConstants.sipMagicByte1;
  }

  /// Generate a cryptographically secure 4-byte nonce.
  static int generateNonce() => _secureRandom.nextInt(0xFFFFFFFF);

  /// Encode a [SipFrame] into a wire-format [Uint8List].
  ///
  /// Returns null if the resulting frame would exceed [SipConstants.sipMtuApp].
  static Uint8List? encode(SipFrame frame) {
    final totalSize = frame.headerLen + frame.payloadLen;
    if (totalSize > SipConstants.sipMtuApp) {
      AppLogging.sip(
        'encode REJECTED: total=$totalSize exceeds MTU=${SipConstants.sipMtuApp}',
      );
      return null;
    }

    final buffer = ByteData(totalSize);
    var offset = 0;

    // Magic bytes
    buffer.setUint8(offset++, SipConstants.sipMagicByte0);
    buffer.setUint8(offset++, SipConstants.sipMagicByte1);

    // Version
    buffer.setUint8(offset++, frame.versionMajor);
    buffer.setUint8(offset++, frame.versionMinor);

    // Message type
    buffer.setUint8(offset++, frame.msgType.code);

    // Flags
    buffer.setUint8(offset++, frame.flags);

    // Header length (LE)
    buffer.setUint16(offset, frame.headerLen, Endian.little);
    offset += 2;

    // Session ID (LE)
    buffer.setUint32(offset, frame.sessionId, Endian.little);
    offset += 4;

    // Nonce (LE)
    buffer.setUint32(offset, frame.nonce, Endian.little);
    offset += 4;

    // Timestamp (LE)
    buffer.setUint32(offset, frame.timestampS, Endian.little);
    offset += 4;

    // Payload length (LE)
    buffer.setUint16(offset, frame.payloadLen, Endian.little);
    offset += 2;

    // Header extensions (TLV)
    for (final ext in frame.headerExtensions) {
      buffer.setUint8(offset++, ext.type);
      buffer.setUint8(offset++, ext.value.length);
      for (var i = 0; i < ext.value.length; i++) {
        buffer.setUint8(offset++, ext.value[i]);
      }
    }

    // Payload
    final result = buffer.buffer.asUint8List();
    for (var i = 0; i < frame.payload.length; i++) {
      result[frame.headerLen + i] = frame.payload[i];
    }

    AppLogging.sip(
      'encode msg_type=0x${frame.msgType.code.toRadixString(16)} '
      'payload=${frame.payloadLen}B total=${totalSize}B',
    );

    return result;
  }

  /// Decode a wire-format [Uint8List] into a [SipFrame].
  ///
  /// Returns null if the data is invalid (wrong magic, truncated, etc.).
  static SipFrame? decode(Uint8List data) {
    // Minimum frame size is the wrapper with zero-length payload.
    if (data.length < SipConstants.sipWrapperMin) {
      AppLogging.sip(
        'decode REJECTED: too short (${data.length} < ${SipConstants.sipWrapperMin})',
      );
      return null;
    }

    // Validate magic bytes.
    if (data[0] != SipConstants.sipMagicByte0 ||
        data[1] != SipConstants.sipMagicByte1) {
      AppLogging.sip(
        'decode REJECTED: invalid magic 0x${data[0].toRadixString(16)}${data[1].toRadixString(16)}',
      );
      return null;
    }

    final bd = ByteData.sublistView(data);

    final versionMajor = bd.getUint8(2);
    final versionMinor = bd.getUint8(3);

    // Version negotiation: drop if major > 0.
    if (versionMajor > 0) {
      AppLogging.sip(
        'decode REJECTED: unsupported version_major=$versionMajor',
      );
      return null;
    }

    final msgTypeCode = bd.getUint8(4);
    // Closed-by-default handshake surface: opcodes in the SIP-1
    // handshake reserved range (0x13..0x17) that are not one of the
    // five known handshake message types are dropped here, before
    // the dispatcher ever sees them. Plan: §5.1a.
    if (isHandshakeOpcodeRange(msgTypeCode) &&
        !isKnownHandshakeOpcode(msgTypeCode)) {
      AppLogging.sip(
        'decode REJECTED: unknown handshake msg_type='
        '0x${msgTypeCode.toRadixString(16)} '
        '(handshake range reserved; closed-by-default)',
      );
      return null;
    }
    final msgType = SipMessageType.fromCode(msgTypeCode);
    if (msgType == null) {
      AppLogging.sip(
        'decode REJECTED: unknown msg_type=0x${msgTypeCode.toRadixString(16)}',
      );
      return null;
    }
    // Strict version_minor enforcement for handshake frames. v0.2 is
    // the only supported handshake wire format; v0.1 frames are
    // dropped with no fallback. Plan: §5.1.
    if (msgType.isHandshake && versionMinor != SipConstants.sipVersionMinor) {
      AppLogging.sip(
        'decode REJECTED: unsupported version_minor=$versionMinor '
        'for msgType=${msgType.name} '
        '(expected ${SipConstants.sipVersionMinor})',
      );
      return null;
    }

    final flags = bd.getUint8(5);
    final headerLen = bd.getUint16(6, Endian.little);

    // Header length must be at least the minimum wrapper.
    if (headerLen < SipConstants.sipWrapperMin) {
      AppLogging.sip(
        'decode REJECTED: header_len=$headerLen < ${SipConstants.sipWrapperMin}',
      );
      return null;
    }

    // Header length must not exceed total data.
    if (headerLen > data.length) {
      AppLogging.sip(
        'decode REJECTED: header_len=$headerLen > data.length=${data.length}',
      );
      return null;
    }

    final sessionId = bd.getUint32(8, Endian.little);
    final nonce = bd.getUint32(12, Endian.little);
    final timestampS = bd.getUint32(16, Endian.little);
    final payloadLen = bd.getUint16(20, Endian.little);

    // Validate total size.
    final totalSize = headerLen + payloadLen;
    if (totalSize > data.length) {
      AppLogging.sip(
        'decode REJECTED: total=$totalSize > data.length=${data.length}',
      );
      return null;
    }

    if (totalSize > SipConstants.sipMtuApp) {
      AppLogging.sip(
        'decode REJECTED: total=$totalSize > MTU=${SipConstants.sipMtuApp}',
      );
      return null;
    }

    // Parse TLV header extensions.
    final headerExtensions = <SipTlvEntry>[];
    if (headerLen > SipConstants.sipWrapperMin) {
      var extOffset = SipConstants.sipWrapperMin;
      while (extOffset + 2 <= headerLen) {
        final tlvType = data[extOffset];
        final tlvLen = data[extOffset + 1];
        extOffset += 2;
        if (extOffset + tlvLen > headerLen) break;
        headerExtensions.add(
          SipTlvEntry(
            type: tlvType,
            value: Uint8List.fromList(
              data.sublist(extOffset, extOffset + tlvLen),
            ),
          ),
        );
        extOffset += tlvLen;
      }
    }

    // Extract payload.
    final payload = Uint8List.fromList(
      data.sublist(headerLen, headerLen + payloadLen),
    );

    AppLogging.sip(
      'decode ${data.length}B -> msg_type=0x${msgTypeCode.toRadixString(16)} '
      'session_id=${sessionId.toRadixString(16)} payload=${payloadLen}B',
    );

    return SipFrame(
      versionMajor: versionMajor,
      versionMinor: versionMinor,
      msgType: msgType,
      flags: flags,
      headerLen: headerLen,
      sessionId: sessionId,
      nonce: nonce,
      timestampS: timestampS,
      payloadLen: payloadLen,
      headerExtensions: headerExtensions,
      payload: payload,
    );
  }

  /// Build an ERROR frame with coded payload.
  static SipFrame buildError({
    required SipErrorCode errorCode,
    required int refMsgType,
    int detail = 0,
    int nonce = 0,
  }) {
    final payload = Uint8List(3);
    payload[0] = errorCode.code;
    payload[1] = refMsgType;
    payload[2] = detail;

    return SipFrame(
      versionMajor: SipConstants.sipVersionMajor,
      versionMinor: SipConstants.sipVersionMinor,
      msgType: SipMessageType.error,
      flags: SipFlags.isResponse,
      headerLen: SipConstants.sipWrapperMin,
      sessionId: 0,
      nonce: nonce == 0 ? generateNonce() : nonce,
      timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      payloadLen: 3,
      payload: payload,
    );
  }

  /// Validate timestamp is within the acceptable drift window.
  static bool isTimestampValid(int frameTimestampS) {
    final nowS = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = (nowS - frameTimestampS).abs();
    return diff <= SipConstants.timestampWindowS;
  }
}
