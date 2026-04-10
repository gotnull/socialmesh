// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Portnum allocations within the Meshtastic private range (256-511).
///
/// These values are used as the `portnum` field in `MeshPacket.decoded.portnum`.
/// Stock Meshtastic firmware routes these identically to any other portnum.
abstract final class SmPortnum {
  /// Legacy JSON-encoded signals (backward compatible with existing releases).
  static const int legacy = 256;

  /// Compact binary presence beacon.
  static const int presence = 260;

  /// Binary-encoded signal broadcast.
  static const int signal = 261;

  /// NodeDex identity digest.
  static const int identity = 262;

  /// File transfer packets (offer, chunk, nack, ack).
  static const int fileTransfer = 263;

  /// All Socialmesh portnums for capability detection.
  static const Set<int> all = {presence, signal, identity, fileTransfer};

  /// Returns true if the portnum is a Socialmesh extension portnum.
  static bool isSocialmesh(int portnum) => all.contains(portnum);
}

/// Protocol version. High nibble of the header byte.
abstract final class SmVersion {
  /// Current protocol version.
  static const int current = 0;

  /// Maximum supported version for forward compatibility.
  /// Bumped to 1 to accept SPP v1 file-transfer packets (kinds 4–7).
  static const int maxSupported = 1;
}

/// Packet kind values (low nibble of hdr0). Globally unique across portnums.
abstract final class SmPacketKind {
  /// SM_PRESENCE.
  static const int presence = 1;

  /// SM_SIGNAL.
  static const int signal = 2;

  /// SM_IDENTITY.
  static const int identity = 3;

  /// SM_FILE_OFFER.
  static const int fileOffer = 4;

  /// SM_FILE_CHUNK.
  static const int fileChunk = 5;

  /// SM_FILE_NACK.
  static const int fileNack = 6;

  /// SM_FILE_ACK.
  static const int fileAck = 7;

  /// SPP_ACCEPT (SPP v1 negotiation).
  static const int sppAccept = 8;

  /// SPP_DECLINE (SPP v1 negotiation).
  static const int sppDecline = 9;

  /// SPP_ABORT (SPP v1 cancel).
  static const int sppAbort = 0x0A;
}

/// Rate limiting intervals for each packet type.
abstract final class SmRateLimit {
  /// Minimum interval between presence beacons.
  static const Duration presenceInterval = Duration(minutes: 5);

  /// Minimum interval between signal broadcasts.
  static const Duration signalInterval = Duration(seconds: 30);

  /// Maximum emergency signals per hour.
  static const int maxEmergencyPerHour = 3;

  /// Minimum interval between unsolicited identity broadcasts.
  static const Duration identityBroadcastInterval = Duration(minutes: 30);

  /// Minimum interval between identity requests to the same node.
  static const Duration identityRequestInterval = Duration(minutes: 10);

  /// Minimum interval between file transfer chunks.
  static const Duration fileChunkInterval = Duration(seconds: 2);

  /// Minimum interval between file offers.
  static const Duration fileOfferInterval = Duration(seconds: 30);

  /// Maximum concurrent outbound file transfers.
  static const int maxConcurrentTransfers = 2;

  /// Maximum retries per chunk.
  static const int maxChunkRetries = 3;

  /// Maximum retries for the initial offer send.
  static const int maxOfferRetries = 3;

  /// Delay between offer send retries.
  static const Duration offerRetryDelay = Duration(seconds: 3);

  /// Maximum NACK retransmission rounds.
  static const int maxNackRounds = 3;

  /// Inactivity timeout for inbound chunk reception.
  ///
  /// If no new chunk arrives within this duration while the transfer
  /// still has missing chunks, the receiver automatically sends a NACK
  /// to request retransmission. Set to 5× the chunk interval to account
  /// for mesh propagation delays on multi-hop paths.
  static const Duration chunkInactivityTimeout = Duration(seconds: 10);

  /// How long the sender waits for receiver ACK after sending all chunks.
  ///
  /// After the sender finishes transmitting every chunk, the transfer
  /// remains active to service late NACKs. If neither an ACK nor a NACK
  /// arrives within this window, the sender marks the transfer complete
  /// as a safety valve (receiver may have completed with lost ACK, or
  /// may be unreachable). Must be long enough for the receiver to detect
  /// missing chunks and exhaust its NACK rounds:
  /// [chunkInactivityTimeout] × [maxNackRounds] + margin.
  static const Duration senderCompletionTimeout = Duration(seconds: 60);
}

/// Transport parameters for each packet type.
abstract final class SmTransport {
  /// Default hop limit for presence beacons (local range).
  static const int presenceHopLimit = 2;

  /// Default hop limit for signals.
  static const int signalHopLimit = 3;

  /// Hop limit for emergency signals.
  static const int emergencyHopLimit = 5;

  /// Default hop limit for unsolicited identity broadcasts.
  static const int identityBroadcastHopLimit = 1;

  /// Hop limit for identity request/response (needs to reach specific node).
  static const int identityRequestHopLimit = 3;

  /// Hop limit for file transfer packets.
  static const int fileTransferHopLimit = 3;
}

/// Maximum payload sizes for validation.
abstract final class SmPayloadLimit {
  /// Maximum presence status string length in bytes.
  static const int presenceStatusMaxBytes = 63;

  /// Maximum signal content string length in bytes.
  static const int signalContentMaxBytes = 140;

  /// LoRa MTU target ceiling for the Data.payload field.
  ///
  /// Actual maximum depends on radio settings (SF, BW, CR) and regional
  /// regulatory constraints. All SM packets enforce hard content caps well
  /// below this ceiling (presence: 63 B, signal: 140 B content).
  static const int loraMtu = 237;
}

/// Hard limits for file transfers to prevent mesh pollution.
abstract final class SmFileTransferLimits {
  /// Maximum total file size in bytes (default 8 KB, configurable for dev).
  static const int maxFileSize = 8192;

  /// Default chunk size in bytes (fits within LoRa MTU minus headers).
  /// 23 bytes header overhead (1 header + 16 fileId + 2 index + 2 count + 2 len)
  /// → ~200 bytes usable payload per chunk.
  static const int defaultChunkSize = 200;

  /// Wire overhead per SPP file chunk in bytes:
  /// 1 header + 16 fileId + 2 chunkIndex + 2 chunkCount + 2 bytesLen = 23.
  static const int chunkHeaderOverhead = 23;

  /// Maximum number of missing chunk indexes in a NACK.
  static const int maxNackIndexes = 16;

  /// Transfer TTL — partial transfers expire after this duration.
  static const Duration transferTtl = Duration(hours: 24);

  /// Maximum allowed filename length in bytes (UTF-8).
  static const int maxFilenameBytes = 64;

  /// Maximum allowed MIME type length in bytes (UTF-8).
  static const int maxMimeTypeBytes = 64;
}
