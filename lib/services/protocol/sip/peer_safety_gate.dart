// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Read-only sync interface that protocol-layer code uses to consult
/// the local Trust + Safety state.
///
/// The protocol layer (SipDmManager, SipHandshakeManager, MRRP
/// dispatcher, etc.) cannot take a Riverpod `Ref`, so it cannot read
/// `peerSafetyManagerProvider` directly. This interface is the
/// dependency-inverted bridge: providers wire up an adapter
/// implementation, the protocol layer queries it sync from the hot
/// path on every inbound and outbound DM frame.
///
/// HARD RULES:
/// - Sync only. The hot path (every inbound SIP frame) cannot await.
/// - Read only. Mutations (block / mute / markFirstHandshake) go
///   through `PeerSafetyManager` directly via the providers layer.
/// - Default-safe — when no implementation is wired (early startup,
///   tests), `isBlocked` MUST return false. Treat the absence of
///   safety state as "everything allowed."
library;

/// Read-only safety gate consulted by SIP protocol code at every
/// inbound + outbound private-DM site.
abstract class PeerSafetyGate {
  /// Whether [peerNodeId] is locally blocked. Hot path; sync.
  ///
  /// When true, the caller must:
  ///   - INBOUND: silently drop the frame, no log at info level, no
  ///     UI surface, no notification, no state mutation.
  ///   - OUTBOUND: fail the send with `SipDmSendError.peerBlocked`.
  bool isBlocked(int peerNodeId);

  /// Whether [peerNodeId] is muted (notifications-only suppression).
  /// Hot path; sync. Block trumps mute everywhere.
  bool isMuted(int peerNodeId);
}

/// No-op gate. Used as the default when no implementation has been
/// wired up (early startup, tests that don't care about safety).
class NoopPeerSafetyGate implements PeerSafetyGate {
  const NoopPeerSafetyGate();

  @override
  bool isBlocked(int peerNodeId) => false;

  @override
  bool isMuted(int peerNodeId) => false;
}
