// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP message types, flags, status codes, TLV types, and service IDs.
///
/// These enums and constants define the wire-level protocol vocabulary
/// for the Mesh Request/Response Protocol v0.1.
library;

/// MRRP message type codes (byte 4 of the MRRP frame header).
enum MrrpMessageType {
  /// Peer advertises available services (broadcast).
  serviceAdvert(0x01),

  /// Request peer's full service directory (to peer).
  serviceDirReq(0x02),

  /// Response with full service directory (to requester).
  serviceDirResp(0x03),

  /// Application request to a service (to peer).
  request(0x10),

  /// Application response from a service (to requester).
  response(0x11),

  /// Structured error response (to requester).
  error(0x12),

  /// Cancel a pending request (to peer).
  cancel(0x13),

  /// Reserved for future event model.
  eventReserved(0x14);

  const MrrpMessageType(this.code);
  final int code;

  /// Look up a message type by its wire code. Returns null if unknown.
  static MrrpMessageType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// MRRP frame flags bitfield (byte 5 of the MRRP frame header).
abstract final class MrrpFlags {
  /// Sender expects a response or ACK.
  static const int ackRequired = 1 << 0;

  /// This frame is a response (not a request).
  static const int isResponse = 1 << 1;

  /// This frame carries an error.
  static const int isError = 1 << 2;

  /// Reserved for future multi-part support.
  static const int moreChunksReserved = 1 << 3;

  /// Mask for defined flag bits (bits 0-3).
  static const int definedMask = 0x0F;

  /// Mask for reserved flag bits (bits 4-7). Must be 0.
  static const int reservedMask = 0xF0;
}

/// MRRP status / error codes.
enum MrrpStatusCode {
  /// Success.
  ok(0),

  /// Service or action not found.
  notFound(1),

  /// Handshake or identity required.
  unauthorized(2),

  /// Peer is busy, try later.
  busy(3),

  /// Request timed out.
  timeout(4),

  /// Malformed request payload.
  invalid(5),

  /// Action not supported by this version.
  unsupported(6),

  /// Budget exhausted, try later.
  rateLimited(7),

  /// Token or session expired.
  expired(8),

  /// Duplicate request suppressed.
  duplicate(9),

  /// Internal error.
  internal(10);

  const MrrpStatusCode(this.code);
  final int code;

  /// Look up a status code by its wire code. Returns null if unknown.
  static MrrpStatusCode? fromCode(int code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return null;
  }
}

/// TLV header extension type codes for MRRP.
enum MrrpTlvType {
  /// First 8 bytes of sender's Ed25519 pubkey.
  senderPubkeyHint(0x01),

  /// uint16 LE, request time-to-live in seconds.
  requestTtlS(0x02),

  /// uint16 LE, response cache TTL in seconds.
  responseTtlS(0x03),

  /// uint32 LE, SIP session_tag for context.
  sessionTagHint(0x04),

  /// uint8, response/error status code.
  statusCode(0x05);

  const MrrpTlvType(this.code);
  final int code;

  /// Look up a TLV type by its wire code. Returns null if unknown.
  static MrrpTlvType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// Well-known MRRP service identifiers.
abstract final class MrrpServiceId {
  /// meetup.v1 — short-lived rendezvous tokens.
  static const int meetupV1 = 0x00000001;

  /// profile.v1 — opt-in peer profile summaries.
  static const int profileV1 = 0x00000002;

  /// board.v1 — short mesh bulletin posts.
  static const int boardV1 = 0x00000003;

  /// incident.v1 — structured incident/emergency reporting.
  static const int incidentV1 = 0x00000004;

  /// pet.v1 — opt-in compact owner-pet public state (~8 B per peer).
  static const int petV1 = 0x00000005;

  /// canvas.v1 — collaborative pixel canvas (MeshCanvas).
  /// Spec: docs/canvas/CANVAS_V0_1.md.
  static const int canvasV1 = 0x00000007;

  /// echo.test — harness-only echo service.
  static const int echoTest = 0xFFFF0001;

  /// Human-readable name for a known service ID.
  static String nameOf(int serviceId) {
    switch (serviceId) {
      case meetupV1:
        return 'meetup.v1'; // lint-allow: hardcoded-string
      case profileV1:
        return 'profile.v1'; // lint-allow: hardcoded-string
      case boardV1:
        return 'board.v1'; // lint-allow: hardcoded-string
      case incidentV1:
        return 'incident.v1'; // lint-allow: hardcoded-string
      case petV1:
        return 'pet.v1'; // lint-allow: hardcoded-string
      case canvasV1:
        return 'canvas.v1'; // lint-allow: hardcoded-string
      case echoTest:
        return 'echo.test'; // lint-allow: hardcoded-string
      default:
        return '0x${serviceId.toRadixString(16).padLeft(8, '0')}'; // lint-allow: hardcoded-string
    }
  }
}

/// MRRP service type codes (byte 4 of service descriptor).
enum MrrpServiceType {
  /// Application service.
  app(0),

  /// System service.
  system(1),

  /// Test service.
  test(2);

  const MrrpServiceType(this.code);
  final int code;

  /// Look up a service type by its wire code. Returns null if unknown.
  static MrrpServiceType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// Service flags bitfield (uint16 in service descriptor).
abstract final class MrrpServiceFlags {
  /// SIP handshake required before requests.
  static const int requiresHandshake = 1 << 0;

  /// SIP identity exchange required.
  static const int requiresIdentity = 1 << 1;

  /// Service accepts REQUEST messages.
  static const int supportsRequest = 1 << 2;

  /// Service sends RESPONSE messages.
  static const int supportsResponse = 1 << 3;

  /// Responses may be cached and replayed.
  static const int supportsCachedResponse = 1 << 4;

  /// Service data is not persisted.
  static const int ephemeralOnly = 1 << 5;

  /// Service should be shown in UI.
  static const int userVisible = 1 << 6;

  /// Service is for testing only.
  static const int testOnly = 1 << 7;
}

/// Well-known action IDs for meetup.v1 service.
abstract final class MeetupAction {
  static const int create = 0x0001;
  static const int accept = 0x0002;
  static const int cancel = 0x0003;
  static const int inspect = 0x0004;
}

/// Well-known action IDs for profile.v1 service.
abstract final class ProfileAction {
  static const int getSummary = 0x0001;
  static const int getContactCard = 0x0002;
  static const int getCapabilities = 0x0003;
}

/// Well-known action IDs for pet.v1 service.
///
/// See `docs/sip/MRRP_SERVICES_V0_1.md` for the spec entry (to be added).
/// Wire format for the get_summary response is the 8-byte PetPublicState
/// codec v1 (schema_tag 0x01). Empty 0-byte response signals "no pet
/// bound yet" — the requester treats this as a silent no-op.
abstract final class PetAction {
  static const int getSummary = 0x0001;
}

/// Well-known action IDs for board.v1 service.
abstract final class BoardAction {
  static const int listRecent = 0x0001;
  static const int postShort = 0x0002;
  static const int getPost = 0x0003;
}

/// Well-known action IDs for echo.test service.
abstract final class EchoAction {
  static const int echo = 0x0001;
  static const int echoError = 0x0002;
  static const int echoDelay = 0x0003;
}

/// Meetup intent type codes.
enum MeetupIntentType {
  general(0),
  emergency(1),
  social(2),
  trade(3);

  const MeetupIntentType(this.code);
  final int code;

  static MeetupIntentType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// Meetup token state codes.
enum MeetupTokenState {
  pending(0),
  accepted(1),
  cancelled(2),
  expired(3);

  const MeetupTokenState(this.code);
  final int code;

  static MeetupTokenState? fromCode(int code) {
    for (final state in values) {
      if (state.code == code) return state;
    }
    return null;
  }
}

/// Profile device class codes.
enum ProfileDeviceClass {
  phone(1),
  tablet(2),
  vehicle(3);

  const ProfileDeviceClass(this.code);
  final int code;

  static ProfileDeviceClass? fromCode(int code) {
    for (final cls in values) {
      if (cls.code == code) return cls;
    }
    return null;
  }
}

/// Profile availability codes.
enum ProfileAvailability {
  unknown(0),
  available(1),
  busy(2),
  away(3);

  const ProfileAvailability(this.code);
  final int code;

  static ProfileAvailability? fromCode(int code) {
    for (final avail in values) {
      if (avail.code == code) return avail;
    }
    return null;
  }
}
