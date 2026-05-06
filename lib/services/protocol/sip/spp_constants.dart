// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SPP v0.1 protocol constants.
///
/// All values are derived from the SocialMesh Payload Protocol specification
/// (docs/protocol/SPP_V0_1.md). SPP payloads ride inside MRRP service
/// payloads. Constants here derive from [MrrpConstants] to guarantee
/// bounded, mesh-safe payloads.
///
/// Spec: docs/protocol/SPP_V0_1.md
library;

import 'mrrp_constants.dart';
import 'spp_types.dart';

/// Core SPP protocol constants.
abstract final class SppConstants {
  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  /// SPP header size: type_id(1) + version(1) = 2 bytes.
  static const int headerSize = sppHeaderSize;

  /// Maximum SPP body after subtracting header from MRRP payload.
  ///
  /// `MRRP_MAX_PAYLOAD - SPP_HEADER` = 195 - 2 = 193 bytes.
  static const int maxBody = MrrpConstants.mrrpMaxPayload - headerSize;

  // ---------------------------------------------------------------------------
  // Incident payload constants
  // ---------------------------------------------------------------------------

  /// Fixed incident header size without location: 15 bytes.
  ///
  /// case_id(4) + seq_num(1) + flags(1) + classification(1) + priority(1)
  /// + status(1) + reporter_role(1) + timestamp(4) + ref_seq(1) = 15.
  static const int incidentHeaderNoLoc = 15;

  /// Fixed incident header size with coarse location: 19 bytes.
  ///
  /// incidentHeaderNoLoc(15) + lat_centi(2) + lon_centi(2) = 19.
  static const int incidentHeaderWithLoc = 19;

  /// Maximum body text bytes for incident without location.
  ///
  /// maxBody(193) - incidentHeaderNoLoc(15) - body_len(1) = 177.
  static const int incidentMaxBodyNoLoc = maxBody - incidentHeaderNoLoc - 1;

  /// Maximum body text bytes for incident with coarse location.
  ///
  /// maxBody(193) - incidentHeaderWithLoc(19) - body_len(1) = 173.
  static const int incidentMaxBodyWithLoc = maxBody - incidentHeaderWithLoc - 1;

  /// Maximum case ID value (uint32).
  static const int maxCaseId = 0xFFFFFFFF;

  /// Maximum sequence number (uint8).
  static const int maxSeqNum = 0xFF;

  /// Sentinel value for ref_seq when no correction reference exists.
  static const int noRefSeq = 0xFF;

  /// Maximum number of incident reports retained per case.
  static const int maxReportsPerCase = 64;

  /// Maximum number of active cases tracked in memory.
  static const int maxActiveCases = 32;

  /// TTL for mesh incident reports before eviction (24 hours).
  static const Duration incidentTtl = Duration(hours: 24);

  /// Minimum interval between re-broadcasting the same report.
  static const Duration incidentRebroadcastCooldown = Duration(minutes: 5);

  // ---------------------------------------------------------------------------
  // Payload budget summary (for documentation and tests)
  // ---------------------------------------------------------------------------

  /// Total LoRa MTU.
  static const int loraMtu = 237;

  /// SIP wrapper overhead (minimum).
  static const int sipOverhead = 22;

  /// MRRP wrapper overhead (minimum).
  static const int mrrpOverhead = 20;

  /// SPP header overhead.
  static const int sppOverhead = headerSize;

  /// Total protocol overhead (SIP + MRRP + SPP, minimum).
  static const int totalOverhead = sipOverhead + mrrpOverhead + sppOverhead;

  /// Net usable bytes for SPP body after all headers (minimum).
  ///
  /// 237 - 22 - 20 - 2 = 193 bytes.
  static const int netUsableBody = loraMtu - totalOverhead;
}
