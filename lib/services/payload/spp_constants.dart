// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SPP (SocialMesh Payload Protocol) v1 constants.
///
/// These constants define the wire format, limits, and timing for SPP v1
/// payload transfers. They are derived from the existing file transfer
/// protocol and extended with negotiation and security features.
///
/// Spec: docs/protocols/SPP_v1.md
abstract final class SppVersion {
  /// SPP v0 (legacy, pre-negotiation).
  static const int v0 = 0;

  /// SPP v1 (current, with mandatory negotiation).
  static const int v1 = 1;

  /// Current protocol version emitted by this implementation.
  static const int current = v1;

  /// Maximum supported version for forward compatibility.
  static const int maxSupported = v1;
}

/// SPP packet kind values (low nibble of header byte).
///
/// Kinds 4-7 are inherited from the v0 file transfer protocol.
/// Kinds 8-10 are new in SPP v1.
abstract final class SppPacketKind {
  /// Payload offer (manifest + metadata).
  static const int offer = 0x04;

  /// Payload chunk (data fragment).
  static const int chunk = 0x05;

  /// Selective retransmission request.
  static const int nack = 0x06;

  /// Transfer completion confirmation.
  static const int ack = 0x07;

  /// Negotiation: accept offer (SPP v1).
  static const int accept = 0x08;

  /// Negotiation: decline offer (SPP v1).
  static const int decline = 0x09;

  /// Cancel in-progress transfer (SPP v1).
  static const int abort = 0x0A;

  /// All valid SPP packet kinds.
  static const Set<int> all = {offer, chunk, nack, ack, accept, decline, abort};

  /// Returns true if the kind nibble is a valid SPP packet kind.
  static bool isValid(int kind) => all.contains(kind);
}

/// SPP payload type identifiers.
///
/// Encoded in the OFFER flags/metadata to indicate the content type.
/// Controls UI presentation and auto-accept rule matching.
abstract final class SppPayloadType {
  /// Generic file.
  static const int file = 0x00;

  /// Compressed image (WebP/JPEG).
  static const int image = 0x01;

  /// Codec2 voice message.
  static const int voice = 0x02;

  /// TAK/CoT attachment (reserved).
  static const int tak = 0x03;

  /// Custom/future extension.
  static const int custom = 0xFF;

  /// Human-readable name for a payload type.
  static String name(int type) => switch (type) {
    file => 'file',
    image => 'image',
    voice => 'voice',
    tak => 'tak',
    custom => 'custom',
    _ => 'unknown($type)',
  };
}

/// Decline reason codes sent in DECLINE packets.
abstract final class SppDeclineReason {
  /// User manually declined.
  static const int userDeclined = 0x00;

  /// Payload type not accepted.
  static const int typeNotAllowed = 0x01;

  /// Payload too large for receiver.
  static const int tooLarge = 0x02;

  /// Receiver storage quota exceeded.
  static const int storageFull = 0x03;

  /// Rate limit exceeded.
  static const int rateLimited = 0x04;

  /// Sender not in trust list.
  static const int untrusted = 0x05;

  /// Human-readable name.
  static String name(int reason) => switch (reason) {
    userDeclined => 'user_declined',
    typeNotAllowed => 'type_not_allowed',
    tooLarge => 'too_large',
    storageFull => 'storage_full',
    rateLimited => 'rate_limited',
    untrusted => 'untrusted',
    _ => 'unknown($reason)',
  };
}

/// Abort reason codes sent in ABORT packets.
abstract final class SppAbortReason {
  /// User cancelled the transfer.
  static const int userCancelled = 0x00;

  /// Transfer TTL expired.
  static const int timeout = 0x01;

  /// Unrecoverable error.
  static const int error = 0x02;

  /// Human-readable name.
  static String name(int reason) => switch (reason) {
    userCancelled => 'user_cancelled',
    timeout => 'timeout',
    error => 'error',
    _ => 'unknown($reason)',
  };
}

/// SPP rate limits.
abstract final class SppRateLimit {
  /// Minimum interval between chunk sends.
  static const Duration chunkInterval = Duration(seconds: 2);

  /// Maximum concurrent outbound transfers.
  static const int maxConcurrentOutbound = 2;

  /// Maximum concurrent inbound transfers.
  static const int maxConcurrentInbound = 3;

  /// Maximum concurrent transfers from a single node.
  static const int maxPerNode = 1;

  /// Maximum NACK retransmission rounds.
  static const int maxNackRounds = 3;

  /// Maximum NACK indexes per packet.
  static const int maxNackIndexes = 16;

  /// Maximum offer retries.
  static const int maxOfferRetries = 3;

  /// Delay between offer retries.
  static const Duration offerRetryDelay = Duration(seconds: 3);

  /// Negotiation timeout (how long to wait for ACCEPT/DECLINE).
  static const Duration negotiationTimeout = Duration(seconds: 60);
}

/// SPP payload size and format limits.
abstract final class SppLimits {
  /// Maximum total payload size in bytes.
  static const int maxPayloadSize = 8192;

  /// Default chunk size in bytes.
  static const int defaultChunkSize = 200;

  /// Maximum filename length in UTF-8 bytes.
  static const int maxFilenameBytes = 64;

  /// Maximum MIME type length in UTF-8 bytes.
  static const int maxMimeTypeBytes = 64;

  /// Transfer time-to-live.
  static const Duration transferTtl = Duration(hours: 24);

  /// Maximum total stored payload bytes (10 MB).
  static const int maxTotalStorage = 10 * 1024 * 1024;
}
