// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Hex-encoded test vectors for every SIP message type.
///
/// These vectors are derived byte-for-byte from the hex examples in
/// `docs/sip/SIP_V0_1.md`. If the spec changes, these fixtures MUST
/// be regenerated from the spec.
library;

import 'dart:typed_data';

/// Convert a hex string (with optional spaces) to [Uint8List].
Uint8List hexToBytes(String hex) {
  final clean = hex.replaceAll(RegExp(r'\s+'), '');
  final bytes = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

/// Test vectors from SIP v0.1 specification Section 6.
abstract final class SipTestVectors {
  /// CAP_BEACON (msg_type=0x01, 32 bytes total)
  ///
  /// Spec Section 6.1.
  static final Uint8List capBeacon = hexToBytes(
    '53 4D 00 01 01 00 16 00 00 00 00 00 04 03 02 01'
    '00 00 00 00 0A 00 0B 00 01 01 D7 00 0A 00 00 00',
  );

  /// Expected field values for CAP_BEACON.
  static const capBeaconFields = (
    versionMajor: 0,
    versionMinor: 1,
    msgTypeCode: 0x01,
    flags: 0x00,
    headerLen: 22,
    sessionId: 0,
    nonce: 0x01020304,
    timestampS: 0,
    payloadLen: 10,
    // Payload fields:
    features: 0x000B,
    deviceClass: 0x01,
    maxProtoMinor: 0x01,
    mtuHint: 215,
    rxWindowS: 10,
  );

  /// ROLLCALL_REQ (msg_type=0x04, 22 bytes total, empty payload)
  ///
  /// Spec Section 6.2.
  static final Uint8List rollcallReq = hexToBytes(
    '53 4D 00 01 04 00 16 00 00 00 00 00 04 03 02 01'
    '00 00 00 00 00 00',
  );

  /// Expected field values for ROLLCALL_REQ.
  static const rollcallReqFields = (
    versionMajor: 0,
    versionMinor: 1,
    msgTypeCode: 0x04,
    flags: 0x00,
    headerLen: 22,
    sessionId: 0,
    nonce: 0x01020304,
    timestampS: 0,
    payloadLen: 0,
  );

  /// ROLLCALL_RESP (msg_type=0x05, 32 bytes total)
  ///
  /// Spec Section 6.3.
  static final Uint8List rollcallResp = hexToBytes(
    '53 4D 00 01 05 08 16 00 00 00 00 00 04 03 02 01'
    '00 00 00 00 0A 00 0B 00 01 01 D7 00 0A 00 00 00',
  );

  /// Expected field values for ROLLCALL_RESP.
  static const rollcallRespFields = (
    versionMajor: 0,
    versionMinor: 1,
    msgTypeCode: 0x05,
    flags: 0x08,
    headerLen: 22,
    sessionId: 0,
    nonce: 0x01020304,
    timestampS: 0,
    payloadLen: 10,
  );

  /// ERROR frame (msg_type=0x7E, 25 bytes total)
  ///
  /// Spec Section 6.13.
  static final Uint8List error = hexToBytes(
    '53 4D 00 01 7E 08 16 00 00 00 00 00 04 03 02 01'
    '00 00 00 00 03 00 01 01 00',
  );

  /// Expected field values for ERROR.
  static const errorFields = (
    versionMajor: 0,
    versionMinor: 1,
    msgTypeCode: 0x7E,
    flags: 0x08,
    headerLen: 22,
    sessionId: 0,
    nonce: 0x01020304,
    timestampS: 0,
    payloadLen: 3,
    // Payload: error_code=0x01 (UNSUPPORTED_VERSION), ref_msg_type=0x01, detail=0x00
    errorCode: 0x01,
    refMsgType: 0x01,
    detail: 0x00,
  );

  /// HS_ACCEPT (msg_type=0x16, 35 bytes total — v0.2 layout)
  ///
  /// v0.2 prepends a 4-byte little-endian `target_node_id` (here
  /// `0xB15E74DB`) and widens `dm_ttl_s` from 16 to 32 bits, growing
  /// the payload from 7 to 13 bytes. Wrapper version_minor is now
  /// `0x02`.
  static final Uint8List hsAccept = hexToBytes(
    '53 4D 00 02 16 08 16 00 00 00 00 00 04 03 02 01'
    '00 00 00 00 0D 00 DB 74 5E B1 78 56 34 12 80 51'
    '00 00 01',
  );

  /// Expected values for HS_ACCEPT.
  static const hsAcceptFields = (
    versionMajor: 0,
    versionMinor: 2,
    msgTypeCode: 0x16,
    flags: 0x08,
    headerLen: 22,
    sessionId: 0,
    nonce: 0x01020304,
    timestampS: 0,
    payloadLen: 13,
    // Payload: target_node_id=0xB15E74DB, session_tag=0x12345678,
    // dm_ttl_s=0x00005180 (20864), flags=0x01
    targetNodeId: 0xB15E74DB,
    sessionTag: 0x12345678,
  );

  /// TX_CHUNK with minimal payload (msg_type=0x31, 30 bytes total)
  static final Uint8List txChunkMinimal = hexToBytes(
    '53 4D 00 01 31 00 16 00 78 56 34 12 04 03 02 01'
    '00 00 00 00 08 00 EF BE AD DE 00 00 00 00',
  );

  /// TX_ACK (msg_type=0x32, 36 bytes total)
  static final Uint8List txAck = hexToBytes(
    '53 4D 00 01 32 08 16 00 78 56 34 12 04 03 02 01'
    '00 00 00 00 0E 00 EF BE AD DE 03 00 0F 00 00 00'
    '00 00 00 00',
  );

  /// DM_MSG (msg_type=0x40, 27 bytes total)
  static final Uint8List dmMsg = hexToBytes(
    '53 4D 00 01 40 00 16 00 78 56 34 12 04 03 02 01'
    '00 00 00 00 05 00 48 65 6C 6C 6F',
  );

  /// Expected values for DM_MSG.
  static const dmMsgFields = (
    msgTypeCode: 0x40,
    sessionId: 0x12345678,
    payloadLen: 5,
    // payload: "Hello" in UTF-8
  );
}
