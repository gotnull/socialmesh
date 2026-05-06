// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Feature-flag holder for the SocialMesh Overlay v0.2 stack.
///
/// P2 introduces the `OVERLAY_LINK_ENABLED` gate. When `false` (the
/// default, and the shipped value for v0.2 rollout), every overlay
/// ingress and egress path is inert:
///
/// - [overlayAttachmentProvider] does not attach a handler to
///   `ProtocolService`, so inbound v0.2 frames fall through to the
///   normal MRRP dispatcher (which rejects the unknown msg type, as
///   v0.1 peers would).
/// - Outbound helpers (egress adapter) short-circuit with `false`.
///
/// Two later flags (`OVERLAY_RESOURCE_ENABLED`, `OVERLAY_SECURE_ENABLED`)
/// are defined in `docs/sip/OVERLAY_V0_2.md` §16.2. P5 activates
/// `resourceEnabled` (this file's `fromEnv` now reads the env var).
/// `secureEnabled` remains forced off until v0.3.
///
/// **Dependency invariant:** `resourceEnabled` is inert unless
/// `linkEnabled` is also `true`. The flag holder exposes both bits as
/// raw values so consumers can inspect them independently in tests; the
/// actual "resource requires link" gating happens in
/// [OverlayResourceDispatcher].
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Snapshot of the overlay-related feature flags for a single provider
/// build. Instances are immutable.
@immutable
class OverlayFeatureFlags {
  /// Gate for MRRP v0.2 link ingress, egress, and provider wiring.
  final bool linkEnabled;

  /// Gate for SPP v0.2 resource transfer. P5 lands this flag; the
  /// "resource requires link" invariant is enforced downstream.
  final bool resourceEnabled;

  /// Reserved for v0.3. Gate for the secure envelope. Always `false`
  /// in P2.
  final bool secureEnabled;

  const OverlayFeatureFlags({
    required this.linkEnabled,
    this.resourceEnabled = false,
    this.secureEnabled = false,
  });

  /// Fully disabled overlay. Use when dotenv is unavailable or the
  /// flag is off.
  static const OverlayFeatureFlags disabled = OverlayFeatureFlags(
    linkEnabled: false,
  );

  /// Read the flag snapshot from the current `.env` environment.
  ///
  /// Missing or unparseable values default to `false` — preserving the
  /// locked principle that overlay must be explicitly opt-in per
  /// install.
  ///
  /// `HANDSHAKE_ENABLED=true` is a shorthand that forces all three
  /// overlay flags on; the granular flags still work independently when
  /// the shorthand is off.
  factory OverlayFeatureFlags.fromEnv() {
    final handshake = _readBool('HANDSHAKE_ENABLED');
    return OverlayFeatureFlags(
      linkEnabled: handshake || _readBool('OVERLAY_LINK_ENABLED'),
      resourceEnabled: handshake || _readBool('OVERLAY_RESOURCE_ENABLED'),
      secureEnabled: handshake || _readBool('OVERLAY_SECURE_ENABLED'),
    );
  }

  /// True only if both [linkEnabled] and [resourceEnabled] are set.
  /// Callers SHOULD gate overlay resource traffic on this getter
  /// rather than reading [resourceEnabled] directly — it encodes the
  /// "resource requires link" invariant once.
  bool get resourceActive => linkEnabled && resourceEnabled;

  /// True only if both [linkEnabled] and [secureEnabled] are set.
  /// Secure sessions ride on the canonical overlay link; the flag is
  /// intentionally orthogonal to [resourceEnabled] so a mesh may
  /// advertise secure support without committing to resource
  /// transfer. See `OVERLAY_V0_2.md §25.9`.
  bool get secureActive => linkEnabled && secureEnabled;

  static bool _readBool(String key) {
    try {
      final raw = dotenv.env[key];
      if (raw == null) return false;
      return raw.trim().toLowerCase() == 'true';
    } catch (_) {
      // dotenv not initialised (common in unit tests).
      return false;
    }
  }
}
