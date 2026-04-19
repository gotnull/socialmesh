// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP v0.1 protocol constants.
///
/// All values are derived from the Mesh Request/Response Protocol specification
/// (docs/sip/MRRP_V0_1.md) and the pre-flight verification results in
/// Sprint 013 (docs/sprints/SPRINT_013.md).
///
/// MRRP frames ride inside SIP payloads. Constants here derive from
/// [SipConstants] to guarantee bounded, mesh-safe payloads.
library;

import 'sip_constants.dart';

/// Core MRRP protocol constants.
///
/// All numeric values are compile-time constants derived from the
/// MRRP v0.1 specification. Timing values use [Duration] for type safety.
abstract final class MrrpConstants {
  // ---------------------------------------------------------------------------
  // Magic bytes and version
  // ---------------------------------------------------------------------------

  /// MRRP magic byte 0: ASCII 'M' (0x4D).
  static const int mrrpMagicByte0 = 0x4D; // 'M'

  /// MRRP magic byte 1: ASCII 'R' (0x52).
  static const int mrrpMagicByte1 = 0x52; // 'R'

  /// MRRP protocol version (major).
  static const int mrrpVersionMajor = 0;

  /// MRRP protocol version (minor).
  static const int mrrpVersionMinor = 1;

  // ---------------------------------------------------------------------------
  // Frame size constants
  // ---------------------------------------------------------------------------

  /// Minimum MRRP header size (bytes).
  ///
  /// Fixed header: magic(2) + version_major(1) + version_minor(1) +
  /// msg_type(1) + flags(1) + header_len(2) + request_id(4) +
  /// service_id(4) + action_id(2) + payload_len(2) = 20 bytes.
  static const int mrrpHeaderMin = 20;

  /// Maximum MRRP payload after subtracting the header from SIP payload.
  ///
  /// `SIP_MAX_PAYLOAD - MRRP_HEADER_MIN` = 215 - 20 = 195 bytes.
  static const int mrrpMaxPayload =
      SipConstants.sipMaxPayload - mrrpHeaderMin; // 195

  // ---------------------------------------------------------------------------
  // Service advertisement constants
  // ---------------------------------------------------------------------------

  /// Maximum number of services per SERVICE_ADVERT message.
  static const int mrrpServiceAdvertMaxServices = 8;

  /// Minimum service descriptor size (bytes).
  ///
  /// service_id(4) + service_type(1) + ver_major(1) + ver_minor(1) +
  /// service_flags(2) + metadata_len(1) = 10 bytes.
  static const int mrrpServiceDescriptorMin = 10;

  /// Maximum service descriptor size (bytes).
  ///
  /// descriptor_min(10) + metadata(32) = 42 bytes.
  static const int mrrpServiceDescriptorMax = 42;

  /// Maximum metadata length in a service descriptor (bytes).
  static const int mrrpServiceMetadataMaxLen = 32;

  // ---------------------------------------------------------------------------
  // Timeout constants (raw seconds for wire encoding)
  // ---------------------------------------------------------------------------

  /// Default request timeout in seconds.
  static const int mrrpRequestTimeoutS = 15;

  /// Service directory request timeout in seconds.
  static const int mrrpServiceDirTimeoutS = 10;

  /// Response cache TTL in seconds.
  static const int mrrpResponseCacheTtlS = 60;

  /// Service advertisement cache TTL in seconds.
  static const int mrrpAdvertCacheTtlS = 3600;

  /// Dedup cache entry TTL in seconds.
  static const int mrrpDedupCacheTtlS = 120;

  // ---------------------------------------------------------------------------
  // Timeout constants (Duration for type-safe API usage)
  // ---------------------------------------------------------------------------

  /// Default request timeout.
  static const Duration mrrpRequestTimeout = Duration(
    seconds: mrrpRequestTimeoutS,
  );

  /// Service directory request timeout.
  static const Duration mrrpServiceDirTimeout = Duration(
    seconds: mrrpServiceDirTimeoutS,
  );

  /// Response cache TTL.
  static const Duration mrrpResponseCacheTtl = Duration(
    seconds: mrrpResponseCacheTtlS,
  );

  /// Service advertisement cache TTL.
  static const Duration mrrpAdvertCacheTtl = Duration(
    seconds: mrrpAdvertCacheTtlS,
  );

  /// Dedup cache TTL.
  static const Duration mrrpDedupCacheTtl = Duration(
    seconds: mrrpDedupCacheTtlS,
  );

  // ---------------------------------------------------------------------------
  // Advertisement cadence
  // ---------------------------------------------------------------------------

  /// Base interval between SERVICE_ADVERT broadcasts in seconds.
  static const int mrrpAdvertIntervalS = 600;

  /// Maximum random jitter on advert interval in seconds.
  static const int mrrpAdvertJitterS = 60;

  /// Base interval between SERVICE_ADVERT broadcasts.
  static const Duration mrrpAdvertInterval = Duration(
    seconds: mrrpAdvertIntervalS,
  );

  /// Maximum random jitter on advert interval.
  static const Duration mrrpAdvertJitter = Duration(seconds: mrrpAdvertJitterS);

  // ---------------------------------------------------------------------------
  // Cache size limits
  // ---------------------------------------------------------------------------

  /// Maximum entries in the duplicate request cache.
  static const int mrrpDedupCacheSize = 64;

  /// Maximum entries in the response cache.
  static const int mrrpResponseCacheSize = 32;

  /// Maximum concurrent outgoing requests.
  static const int mrrpMaxPendingRequests = 4;

  /// Maximum peers tracked in the advertisement cache.
  static const int mrrpMaxTrackedPeers = 16;
}
