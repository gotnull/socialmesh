// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP v0.1 protocol constants.
///
/// All values are derived from the Socialmesh Interop Profile specification
/// (docs/sip/SIP_V0_1.md) and the pre-flight verification results in
/// Sprint 011 (docs/sprints/SPRINT_011.md).
///
/// These constants govern frame sizes, airtime budgets, timing intervals,
/// cache sizes, and transfer limits for the SIP protocol layer.
library;

import '../socialmesh/sm_constants.dart';

/// Core SIP protocol constants.
///
/// All numeric values are compile-time constants derived from the
/// SIP v0.1 specification. Timing values use [Duration] for type safety.
abstract final class SipConstants {
  // ---------------------------------------------------------------------------
  // Frame size constants
  // ---------------------------------------------------------------------------

  /// Maximum application-layer payload (bytes) for a single SIP frame.
  ///
  /// Derived from [SmPayloadLimit.loraMtu] -- the Data.payload ceiling
  /// after Meshtastic protobuf encoding.
  static const int sipMtuApp = SmPayloadLimit.loraMtu; // 237

  /// Minimum SIP frame wrapper size (bytes).
  ///
  /// Fixed header: magic(2) + version_major(1) + version_minor(1) +
  /// msg_type(1) + flags(1) + header_len(2) + session_id(4) +
  /// nonce(4) + timestamp_s(4) + payload_len(2) = 22 bytes.
  static const int sipWrapperMin = 22;

  /// Maximum SIP payload after subtracting the wrapper.
  ///
  /// `SIP_MTU_APP - SIP_WRAPPER_MIN` = 237 - 22 = 215 bytes.
  static const int sipMaxPayload = sipMtuApp - sipWrapperMin; // 215

  /// SIP-3 TX_CHUNK header size (bytes).
  ///
  /// file_hash32(4) + chunk_index(2) + chunk_len(2) = 8 bytes.
  static const int sipTxChunkHeader = 8;

  /// Maximum chunk data size for SIP-3 transfers (bytes).
  ///
  /// `SIP_MAX_PAYLOAD - SIP_TX_CHUNK_HEADER` = 215 - 8 = 207 bytes.
  static const int sipChunkSize = sipMaxPayload - sipTxChunkHeader; // 207

  /// Ed25519 signature trailer size (bytes).
  ///
  /// sig_type(1) + sig_len(1) + signature(64) = 66 bytes.
  static const int sipSignatureTrailer = 66;

  /// Maximum payload size when a signature trailer is present.
  ///
  /// `SIP_MAX_PAYLOAD - SIP_SIGNATURE_TRAILER` = 215 - 66 = 149 bytes.
  static const int sipMaxSignedPayload =
      sipMaxPayload - sipSignatureTrailer; // 149

  /// SIP magic bytes: ASCII 'SM' (0x53 0x4D).
  static const int sipMagicByte0 = 0x53; // 'S'
  static const int sipMagicByte1 = 0x4D; // 'M'

  /// SIP protocol version (major).
  static const int sipVersionMajor = 0;

  /// SIP protocol version (minor).
  static const int sipVersionMinor = 1;

  // ---------------------------------------------------------------------------
  // Airtime budget constants
  // ---------------------------------------------------------------------------

  /// Total SIP byte budget per rolling 60-second window.
  ///
  /// All SIP messages combined (beacons, rollcall, identity, handshake,
  /// DM, and transfer) must not exceed this ceiling.
  static const int sipBudgetBytesPer60s = 1024;

  /// TX_CHUNK payload budget within the total SIP budget.
  ///
  /// SIP-3 transfer traffic is further limited to this sub-budget
  /// to leave headroom for discovery and control messages.
  static const int sipTxBudgetBytesPer60s = 768;

  /// Rolling window duration for the token-bucket rate limiter.
  static const Duration sipBudgetWindow = Duration(seconds: 60);

  // ---------------------------------------------------------------------------
  // Timing intervals
  // ---------------------------------------------------------------------------

  /// Base interval between CAP_BEACON emissions (foreground only).
  static const Duration capBeaconInterval = Duration(seconds: 300);

  /// Maximum random jitter added to beacon interval.
  static const Duration capBeaconJitter = Duration(seconds: 30);

  /// Minimum enforced interval between beacons (across resume).
  static const Duration capBeaconMinInterval = Duration(seconds: 300);

  /// Raw seconds for CAP_BEACON interval (used in frame payloads).
  static const int capBeaconIntervalS = 300;

  /// Raw seconds for CAP_BEACON jitter max.
  static const int capBeaconJitterS = 30;

  /// Raw seconds for CAP_BEACON minimum interval.
  static const int capBeaconMinIntervalS = 300;

  /// Minimum interval between ROLLCALL_REQ transmissions.
  static const Duration rollcallMinInterval = Duration(seconds: 60);

  /// Maximum random delay before sending a ROLLCALL_RESP.
  static const Duration rollcallRespDelayMax = Duration(seconds: 3);

  /// Raw seconds for ROLLCALL minimum interval.
  static const int rollcallMinIntervalS = 60;

  /// Raw seconds for ROLLCALL response delay max.
  static const int rollcallRespDelayMaxS = 3;

  /// Minimum interval between ID_CLAIM sends to the same peer.
  static const Duration idClaimMinIntervalPerPeer = Duration(seconds: 300);

  /// Raw seconds for ID_CLAIM minimum interval per peer.
  static const int idClaimMinIntervalPerPeerS = 300;

  // ---------------------------------------------------------------------------
  // Replay cache constants
  // ---------------------------------------------------------------------------

  /// Maximum nonces stored per cache key in the replay cache.
  static const int replayCacheSize = 64;

  /// Time-to-live for replay cache entries.
  static const Duration replayCacheTtl = Duration(seconds: 1800);

  /// Raw seconds for replay cache TTL.
  static const int replayCacheTtlS = 1800;

  /// Acceptable timestamp drift window for frame validation.
  static const Duration timestampWindow = Duration(seconds: 86400);

  /// Raw seconds for timestamp window (24 hours).
  static const int timestampWindowS = 86400;

  // ---------------------------------------------------------------------------
  // Ephemeral DM constants
  // ---------------------------------------------------------------------------

  /// Default time-to-live for ephemeral DM sessions.
  static const Duration dmTtlDefault = Duration(seconds: 86400);

  /// Raw seconds for default DM TTL (24 hours).
  static const int dmTtlDefaultS = 86400;

  // ---------------------------------------------------------------------------
  // Peer tracking limits
  // ---------------------------------------------------------------------------

  /// Maximum number of SIP peers tracked in the capability cache.
  static const int maxTrackedPeers = 16;

  // ---------------------------------------------------------------------------
  // SIP-3 transfer limits
  // ---------------------------------------------------------------------------

  /// Maximum concurrent incoming SIP-3 transfer sessions.
  static const int maxIncomingSessions = 2;

  /// Maximum concurrent outgoing SIP-3 transfer sessions.
  static const int maxOutgoingSessions = 1;

  /// Maximum total transfer size (bytes) for SIP-3.
  static const int maxTransferSize = 8192;

  /// Timeout waiting for TX_START acknowledgement.
  static const Duration txStartAckTimeout = Duration(seconds: 20);

  /// Raw seconds for TX_START ack timeout.
  static const int txStartAckTimeoutS = 20;

  /// Timeout for idle chunk activity (no chunks sent/received).
  static const Duration txChunkIdleTimeout = Duration(seconds: 60);

  /// Raw seconds for chunk idle timeout.
  static const int txChunkIdleTimeoutS = 60;

  /// Total session timeout for a SIP-3 transfer.
  static const Duration txSessionTimeout = Duration(seconds: 600);

  /// Raw seconds for total session timeout (10 minutes).
  static const int txSessionTimeoutS = 600;

  // ---------------------------------------------------------------------------
  // Congestion and backoff
  // ---------------------------------------------------------------------------

  /// Pause duration when non-SIP chat traffic is detected.
  static const Duration congestionPause = Duration(seconds: 10);

  /// Raw seconds for congestion pause.
  static const int congestionPauseS = 10;

  /// Suppression window after app resume to prevent burst sends.
  ///
  /// All non-essential SIP transmissions (beacons, rollcalls, auto-scan)
  /// are suppressed for this duration after the app returns to foreground.
  static const Duration resumeSuppressionWindow = Duration(seconds: 10);

  /// Raw seconds for resume suppression window.
  static const int resumeSuppressionWindowS = 10;

  /// Base duration for exponential backoff on retries.
  static const Duration backoffBase = Duration(seconds: 2);

  /// Raw seconds for backoff base.
  static const int backoffBaseS = 2;

  /// Maximum backoff duration.
  static const Duration backoffMax = Duration(seconds: 60);

  /// Raw seconds for maximum backoff.
  static const int backoffMaxS = 60;

  // ---------------------------------------------------------------------------
  // SIP-3 ACK policy
  // ---------------------------------------------------------------------------

  /// Send TX_ACK every N chunks received.
  static const int ackEveryNChunks = 4;

  // ---------------------------------------------------------------------------
  // CAP_BEACON payload size
  // ---------------------------------------------------------------------------

  /// CAP_BEACON payload size (bytes): features(2) + device_class(1) +
  /// max_proto_minor(1) + mtu_hint(2) + rx_window_s(2) + reserved(2) = 10.
  static const int capBeaconPayloadSize = 10;

  /// Default rx_window_s value for CAP_BEACON.
  static const int defaultRxWindowS = 10;

  /// Device class: phone-app.
  static const int deviceClassPhoneApp = 1;

  // ---------------------------------------------------------------------------
  // Rollcall jitter
  // ---------------------------------------------------------------------------

  /// Maximum random jitter added to rollcall request interval.
  ///
  /// Prevents all SIP nodes from broadcasting ROLLCALL_REQ at the same
  /// instant after cooldown expires (thundering herd mitigation).
  static const Duration rollcallReqJitter = Duration(seconds: 5);

  /// Raw seconds for rollcall request jitter max.
  static const int rollcallReqJitterS = 5;

  // ---------------------------------------------------------------------------
  // Handshake timing
  // ---------------------------------------------------------------------------

  /// Handshake timeout -- must complete within this duration.
  ///
  /// Wire-frozen: this value is sent to the peer in `HS_CHALLENGE.expires_in_s`
  /// per `docs/sip/SIP_V0_1.md` §7.3 / §7.4 and bounds the initiator's
  /// HELLO_SENT, RESPONSE_SENT, and the responder's CHALLENGE_SENT states.
  /// Do not change without a protocol version bump.
  static const Duration handshakeTimeout = Duration(seconds: 60);

  /// Raw seconds for handshake timeout.
  static const int handshakeTimeoutS = 60;

  /// Local-only lifetime of an inbound HS_HELLO that's queued for user
  /// consent. Kept distinct from [handshakeTimeout] (which is wire-bound)
  /// because the consent UI must outlast the peer's retransmit budget —
  /// otherwise a user who takes longer than 60 s to tap Accept finds the
  /// pending request silently expired and their tap rejected with
  /// `acceptHandshake — no valid pending request`. The pending entry's
  /// timestamp is also refreshed on every duplicate HELLO retransmit so
  /// the prompt stays alive while the peer is still trying.
  static const Duration pendingConsentTimeout = Duration(minutes: 5);

  /// Per-peer cooldown after a handshake failure or timeout.
  ///
  /// Prevents tight retry loops on unreachable or unresponsive peers.
  static const Duration handshakeCooldownPerPeer = Duration(seconds: 120);

  /// Raw seconds for handshake cooldown per peer.
  static const int handshakeCooldownPerPeerS = 120;

  /// Maximum completed handshake results retained before eviction.
  static const int maxCompletedResults = 16;

  /// TTL for completed handshake results awaiting consumption.
  static const Duration completedResultTtl = Duration(seconds: 600);

  /// Raw seconds for completed result TTL.
  static const int completedResultTtlS = 600;

  // ---------------------------------------------------------------------------
  // Bounded map limits
  // ---------------------------------------------------------------------------

  /// Maximum per-peer rollcall response timestamps tracked.
  ///
  /// Prevents unbounded growth of the rollcall response rate limiter.
  /// Excess entries are evicted oldest-first.
  static const int maxRollcallRespTracked = 32;
}
