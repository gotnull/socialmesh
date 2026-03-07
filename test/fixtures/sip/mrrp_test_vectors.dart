// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Hex-encoded test vectors for every MRRP message type.
///
/// These vectors are derived byte-for-byte from the MRRP v0.1 specification
/// (docs/sip/MRRP_V0_1.md). If the spec changes, these fixtures MUST
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

/// MRRP test vectors from the MRRP v0.1 specification.
abstract final class MrrpTestVectors {
  // ---------------------------------------------------------------------------
  // SERVICE_ADVERT (msg_type=0x01)
  // ---------------------------------------------------------------------------

  /// SERVICE_ADVERT with 2 services (meetup.v1 + echo.test).
  ///
  /// Header: magic(4D 52) ver(00 01) type(01) flags(00) hdr_len(14 00)
  ///         req_id(00 00 00 00) service_id(00 00 00 00) action_id(00 00)
  ///         payload_len(15 00)
  /// Payload: service_count(02)
  ///   Descriptor 1: service_id(01 00 00 00) type(00) ver(01 00) flags(6D 00) meta_len(00)
  ///   Descriptor 2: service_id(01 00 FF FF) type(02) ver(01 00) flags(8C 00) meta_len(00)
  static final Uint8List serviceAdvert = hexToBytes(
    '4D 52 00 01 01 00 14 00 00 00 00 00 00 00 00 00'
    '00 00 15 00'
    '02'
    '01 00 00 00 00 01 00 6D 00 00'
    '01 00 FF FF 02 01 00 8C 00 00',
  );

  /// Expected field values for SERVICE_ADVERT.
  static const serviceAdvertFields = (
    versionMajor: 0,
    versionMinor: 1,
    msgTypeCode: 0x01,
    flags: 0x00,
    headerLen: 20,
    requestId: 0,
    serviceId: 0,
    actionId: 0,
    payloadLen: 21,
    serviceCount: 2,
  );

  // ---------------------------------------------------------------------------
  // SERVICE_DIR_REQ (msg_type=0x02)
  // ---------------------------------------------------------------------------

  /// SERVICE_DIR_REQ — empty payload request for peer's service directory.
  ///
  /// Header: magic(4D 52) ver(00 01) type(02) flags(01) hdr_len(14 00)
  ///         req_id(01 00 00 00) service_id(00 00 00 00) action_id(00 00)
  ///         payload_len(00 00)
  static final Uint8List serviceDirReq = hexToBytes(
    '4D 52 00 01 02 01 14 00 01 00 00 00 00 00 00 00'
    '00 00 00 00',
  );

  /// Expected field values for SERVICE_DIR_REQ.
  static const serviceDirReqFields = (
    versionMajor: 0,
    versionMinor: 1,
    msgTypeCode: 0x02,
    flags: 0x01,
    headerLen: 20,
    requestId: 1,
    serviceId: 0,
    actionId: 0,
    payloadLen: 0,
  );

  // ---------------------------------------------------------------------------
  // SERVICE_DIR_RESP (msg_type=0x03)
  // ---------------------------------------------------------------------------

  /// SERVICE_DIR_RESP with 1 service (profile.v1).
  ///
  /// Header: magic(4D 52) ver(00 01) type(03) flags(02) hdr_len(14 00)
  ///         req_id(01 00 00 00) service_id(00 00 00 00) action_id(00 00)
  ///         payload_len(0B 00)
  /// Payload: service_count(01)
  ///   Descriptor: service_id(02 00 00 00) type(00) ver(01 00) flags(7F 00) meta_len(00)
  static final Uint8List serviceDirResp = hexToBytes(
    '4D 52 00 01 03 02 14 00 01 00 00 00 00 00 00 00'
    '00 00 0B 00'
    '01'
    '02 00 00 00 00 01 00 7F 00 00',
  );

  /// Expected field values for SERVICE_DIR_RESP.
  static const serviceDirRespFields = (
    versionMajor: 0,
    versionMinor: 1,
    msgTypeCode: 0x03,
    flags: 0x02,
    headerLen: 20,
    requestId: 1,
    serviceId: 0,
    actionId: 0,
    payloadLen: 11,
    serviceCount: 1,
  );

  // ---------------------------------------------------------------------------
  // REQUEST (msg_type=0x10)
  // ---------------------------------------------------------------------------

  /// REQUEST to echo.test service, action=echo, 4 bytes payload.
  ///
  /// Header: magic(4D 52) ver(00 01) type(10) flags(01) hdr_len(14 00)
  ///         req_id(42 00 00 00) service_id(01 00 FF FF) action_id(01 00)
  ///         payload_len(04 00)
  /// Payload: DE AD BE EF
  static final Uint8List request = hexToBytes(
    '4D 52 00 01 10 01 14 00 42 00 00 00 01 00 FF FF'
    '01 00 04 00'
    'DE AD BE EF',
  );

  /// Expected field values for REQUEST.
  static const requestFields = (
    versionMajor: 0,
    versionMinor: 1,
    msgTypeCode: 0x10,
    flags: 0x01,
    headerLen: 20,
    requestId: 0x42,
    serviceId: 0xFFFF0001,
    actionId: 0x0001,
    payloadLen: 4,
  );

  // ---------------------------------------------------------------------------
  // RESPONSE (msg_type=0x11)
  // ---------------------------------------------------------------------------

  /// RESPONSE from echo.test service, echoed 4 bytes payload.
  ///
  /// Header: magic(4D 52) ver(00 01) type(11) flags(02) hdr_len(14 00)
  ///         req_id(42 00 00 00) service_id(01 00 FF FF) action_id(01 00)
  ///         payload_len(04 00)
  /// Payload: DE AD BE EF
  static final Uint8List response = hexToBytes(
    '4D 52 00 01 11 02 14 00 42 00 00 00 01 00 FF FF'
    '01 00 04 00'
    'DE AD BE EF',
  );

  /// Expected field values for RESPONSE.
  static const responseFields = (
    versionMajor: 0,
    versionMinor: 1,
    msgTypeCode: 0x11,
    flags: 0x02,
    headerLen: 20,
    requestId: 0x42,
    serviceId: 0xFFFF0001,
    actionId: 0x0001,
    payloadLen: 4,
  );

  // ---------------------------------------------------------------------------
  // ERROR (msg_type=0x12)
  // ---------------------------------------------------------------------------

  /// ERROR response with status=NOT_FOUND.
  ///
  /// Header: magic(4D 52) ver(00 01) type(12) flags(06) hdr_len(17 00)
  ///         req_id(42 00 00 00) service_id(00 00 DE AD) action_id(01 00)
  ///         payload_len(00 00)
  /// TLV: status_code(05 01 01) — type=0x05, len=1, value=0x01 (NOT_FOUND)
  static final Uint8List error = hexToBytes(
    '4D 52 00 01 12 06 17 00 42 00 00 00 00 00 DE AD'
    '01 00 00 00'
    '05 01 01',
  );

  /// Expected field values for ERROR.
  static const errorFields = (
    versionMajor: 0,
    versionMinor: 1,
    msgTypeCode: 0x12,
    flags: 0x06,
    headerLen: 23,
    requestId: 0x42,
    serviceId: 0xADDE0000,
    actionId: 0x0001,
    payloadLen: 0,
    statusCode: 1,
  );

  // ---------------------------------------------------------------------------
  // CANCEL (msg_type=0x13)
  // ---------------------------------------------------------------------------

  /// CANCEL for a pending request.
  ///
  /// Header: magic(4D 52) ver(00 01) type(13) flags(00) hdr_len(14 00)
  ///         req_id(42 00 00 00) service_id(01 00 FF FF) action_id(01 00)
  ///         payload_len(00 00)
  static final Uint8List cancel = hexToBytes(
    '4D 52 00 01 13 00 14 00 42 00 00 00 01 00 FF FF'
    '01 00 00 00',
  );

  /// Expected field values for CANCEL.
  static const cancelFields = (
    versionMajor: 0,
    versionMinor: 1,
    msgTypeCode: 0x13,
    flags: 0x00,
    headerLen: 20,
    requestId: 0x42,
    serviceId: 0xFFFF0001,
    actionId: 0x0001,
    payloadLen: 0,
  );

  // ---------------------------------------------------------------------------
  // REQUEST with TLV header extensions
  // ---------------------------------------------------------------------------

  /// REQUEST with request_ttl_s TLV extension (type=0x02, 2 bytes).
  ///
  /// Header: magic(4D 52) ver(00 01) type(10) flags(01) hdr_len(18 00)
  ///         req_id(07 00 00 00) service_id(01 00 00 00) action_id(01 00)
  ///         payload_len(00 00)
  /// TLV: request_ttl_s(02 02 0F 00) — type=0x02, len=2, value=15 (LE uint16)
  static final Uint8List requestWithTlv = hexToBytes(
    '4D 52 00 01 10 01 18 00 07 00 00 00 01 00 00 00'
    '01 00 00 00'
    '02 02 0F 00',
  );

  /// Expected field values for REQUEST with TLV.
  static const requestWithTlvFields = (
    versionMajor: 0,
    versionMinor: 1,
    msgTypeCode: 0x10,
    flags: 0x01,
    headerLen: 24,
    requestId: 7,
    serviceId: 0x00000001,
    actionId: 0x0001,
    payloadLen: 0,
    tlvCount: 1,
    tlvRequestTtlS: 15,
  );
}
