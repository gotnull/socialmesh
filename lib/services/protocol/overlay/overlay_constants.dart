// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Byte-accurate constants for the SocialMesh Overlay v0.2 stack.
///
/// Every value here is anchored to `docs/sip/OVERLAY_V0_2.md`. If the
/// spec disagrees, the spec wins and this file is wrong. Budgets also
/// reference `docs/sip/SIP_V0_1.md` and `docs/sip/MRRP_V0_1.md` for
/// the base SIP/MRRP envelope sizes.
///
/// P0 (codec-only phase) uses these constants in encode/decode and in
/// test-vector validation. No engine or provider code depends on them
/// yet.
library;

/// Fixed-layout constants for MRRP v0.2 link frames.
abstract final class OverlayLinkConstants {
  /// Base MRRP v0.1 header size. Matches `MrrpConstants.mrrpHeaderMin`.
  static const int baseMrrpHeader = 20;

  /// Extra bytes added to the header when the `linkFrame` flag is set:
  /// `linkId(4) + seq(2) + ackHi(2) = 8`.
  static const int linkExtensionBytes = 8;

  /// Full header length when `linkFrame == 1`.
  static const int headerLen = baseMrrpHeader + linkExtensionBytes; // 28

  /// MRRP v0.2 major version.
  static const int versionMajor = 0;

  /// MRRP v0.2 minor version.
  static const int versionMinor = 2;

  /// SIP wrapper size that an unsigned v0.2 link frame will ride in.
  /// Matches `SipConstants.sipHeaderMin` (22).
  static const int sipWrapperBytes = 22;

  /// SIP signed wrapper total cost = 22 header + 66 trailer.
  static const int sipSignedWrapperBytes = 88;

  /// Meshtastic data.payload ceiling. Matches
  /// `SmPayloadLimit.loraMtu`.
  static const int loraMtu = 237;

  /// Bytes available for an MRRP v0.2 *payload* when carried inside an
  /// unsigned SIP frame: 237 - 22 - 28 = 187.
  static const int payloadCeilUnsigned =
      loraMtu - sipWrapperBytes - headerLen; // 187

  /// Bytes available for an MRRP v0.2 *payload* when carried inside a
  /// signed SIP frame: 237 - 88 - 28 = 121.
  static const int payloadCeilSigned =
      loraMtu - sipSignedWrapperBytes - headerLen; // 121

  /// Sender window in number of unacknowledged frames (§10.5).
  static const int sendWindow = 4;

  /// Absolute cap on header extensions for forward-compat safety.
  /// v0.2 does not add TLVs beyond the fixed 8-byte link extension.
  static const int maxHeaderBytes = 64;

  /// Minimum LINK_PING cadence in seconds (§10.4).
  static const int pingCadenceSecMin = 270;

  /// Maximum LINK_PING cadence in seconds (§10.4) — nominal target
  /// 300 s with jitter up to 30 s.
  static const int pingCadenceSecMax = 330;

  /// STALE transition threshold in seconds: 2× maximum ping cadence.
  static const int staleThresholdSec = 2 * pingCadenceSecMax; // 660

  /// LINK_OPEN initial retry backoff in seconds.
  static const int openRetryBaseSec = 8;

  /// LINK_OPEN maximum retry backoff in seconds.
  static const int openRetryCapSec = 64;

  /// LINK_OPEN maximum retry count.
  static const int openMaxTries = 4;

  /// Handshake window in seconds — mirrors `SipConstants.handshakeTimeout`
  /// (60 s per SIP v0.1 §).
  static const int handshakeWindowSec = 60;

  /// Link maximum lifetime in seconds (24 h; forces periodic re-handshake).
  static const int linkMaxLifetimeSec = 24 * 60 * 60;

  /// Closed-link audit retention in seconds before GC.
  static const int closedRetentionSec = 24 * 60 * 60;
}

/// Fixed-layout constants for SPP v0.2 resource frames.
abstract final class OverlayResourceConstants {
  /// SPP v0.2 header: type(1) + version(1) + resourceId(4) +
  /// chunkIndex(2) + chunkCount(2) = 10 bytes.
  static const int headerLen = 10;

  /// SPP v0.2 protocol version byte.
  static const int version = 0x02;

  /// Chunk payload ceiling when carried through an unsigned SIP +
  /// v0.2 MRRP linkFrame: 187 - 10 = 177 B.
  static const int chunkPayloadCeilUnsigned =
      OverlayLinkConstants.payloadCeilUnsigned - headerLen; // 177

  /// Chunk payload ceiling through a signed SIP wrapper:
  /// 121 - 10 = 111 B. Signed chunks are permitted by the codec but
  /// forbidden at the policy layer per §11 — chunks are always sent
  /// unsigned; integrity is end-to-end via COMPLETE SHA-256.
  static const int chunkPayloadCeilSigned =
      OverlayLinkConstants.payloadCeilSigned - headerLen; // 111

  /// Default chunk size in bytes (§11.3). Leaves headroom under the
  /// unsigned ceiling for future TLV extensions.
  static const int chunkSizeDefault = 128;

  /// Reduced chunk size used when future `secure` mode is enabled
  /// (§12.2).
  static const int chunkSizeSecure = 96;

  /// Maximum chunk index — u16 limit. `chunkCount` at max = 65 536.
  static const int maxChunkIndex = 0xFFFF;

  /// Maximum resource size in bytes (v0.2 cap per §11.7).
  static const int maxResourceBytes = 65535;

  /// Maximum concurrent transfers per link.
  static const int maxConcurrentPerLink = 2;

  /// Maximum transfers per peer per 24 h.
  static const int maxTransfersPerPeerPerDay = 32;

  /// Partial chunk retention in seconds (§11.7).
  static const int partialRetentionSec = 72 * 60 * 60;

  /// Completed transfer metadata retention in seconds.
  static const int completeMetaRetentionSec = 30 * 24 * 60 * 60;

  /// Bytes per chunk ACK window before sender pauses for BITMAP
  /// (§11.6). Matches `sendWindow` so that one BITMAP covers the window.
  static const int chunksPerAckWindow = OverlayLinkConstants.sendWindow;

  /// Sender delay between windows awaiting BITMAP, in milliseconds.
  static const int windowPauseMs = 500;

  /// Max RESUME retries over a 120 s window.
  static const int maxResumeRetries = 4;

  /// Receiver silence timeout (failure) in seconds.
  static const int receiverSilenceFailSec = 600;
}

/// Constants for the overlay capability announcement carried inside
/// `CAP_BEACON` and `ID_CLAIM` frames.
abstract final class OverlayCapabilityConstants {
  /// TLV header overhead: 1 byte type + 1 byte length.
  static const int tlvHeaderBytes = 2;

  /// Payload width of `supportedFeatures`.
  static const int supportedFeaturesBytes = 4;

  /// Payload width of `maxChunkBytes`.
  static const int maxChunkBytesBytes = 2;

  /// Payload width of `maxResourceBytes`.
  static const int maxResourceBytesBytes = 4;

  /// Maximum bytes a full capability TLV block may consume, across all
  /// three defined TLVs. Sized to fit comfortably under MRRP's 195 B
  /// payload ceiling alongside a CAP_BEACON body.
  static const int maxBlockBytes =
      3 * tlvHeaderBytes +
      supportedFeaturesBytes +
      maxChunkBytesBytes +
      maxResourceBytesBytes;
}

/// Shared values applying to the entire overlay stack.
abstract final class OverlayCommonConstants {
  /// Spec version string (for diagnostics, not on the wire).
  static const String specVersion = 'overlay/v0.2';

  /// Debug-only feature name passed to `AppLogging.overlay` so grep
  /// filters can target just the overlay.
  static const String logFeature = 'overlay';
}
