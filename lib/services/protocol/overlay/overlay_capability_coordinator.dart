// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Small, focused capability-tracking component for the overlay link
/// layer.
///
/// Per the P2 scope directive, this coordinator keeps capability logic
/// from leaking into [OverlayLinkEngine] or [ProtocolService]. It
/// records observations about remote peers' overlay support and
/// answers a single question: "may I attempt to open a link with this
/// peer?".
///
/// P2 keeps snapshots **in memory**. Persistence lands in P3 alongside
/// identity binding (`endpoints.db` in `docs/sip/OVERLAY_V0_2.md`
/// §13.3). For P2, a process restart means capability observations
/// start empty — acceptable because the only consumer is `openLocal`,
/// which is not yet wired to any product flow.
library;

import 'package:flutter/foundation.dart';

import '../../../core/logging.dart';
import 'overlay_link_models.dart';

/// Where the capability snapshot was observed from. Useful for
/// diagnostics and future trust-level decisions (P3+).
enum OverlayCapabilityObservationSource {
  /// Parsed from a peer's `CAP_BEACON` TLV. Outbound advertisement of
  /// our own `CAP_BEACON` TLV is deferred post-P2 to avoid mesh
  /// chatter; receive-only is a safe one-way start.
  capBeacon,

  /// Parsed from a peer's `ID_CLAIM` TLV.
  idClaim,

  /// Inferred from successful receipt of an overlay link frame
  /// (`LINK_OPEN`, `LINK_OPEN_OK`, etc.). The mere presence of a
  /// well-formed v0.2 frame is proof that the sender supports the
  /// link layer.
  linkFrame,
}

/// An observed capability snapshot for a single peer.
@immutable
class OverlayCapabilitySnapshot {
  /// Features and limits the peer advertised or demonstrated.
  final OverlayLinkCapabilities capabilities;

  /// Wall-clock ms when this snapshot was taken.
  final int observedAtMs;

  /// Where the observation came from.
  final OverlayCapabilityObservationSource source;

  const OverlayCapabilitySnapshot({
    required this.capabilities,
    required this.observedAtMs,
    required this.source,
  });

  /// True if the peer advertises MRRP v0.2 link support.
  bool get supportsLink => capabilities.supportsLink;

  /// True if the peer advertises SPP v0.2 resource support (not
  /// consulted in P2; kept here for forward symmetry).
  bool get supportsResource => capabilities.supportsResource;

  @override
  String toString() =>
      'OverlayCapabilitySnapshot(src=${source.name}, '
      'at=$observedAtMs, ${capabilities.toString()})';
}

/// In-memory tracker of per-peer capability snapshots.
///
/// Keyed by `peerNodeNum`. Once P3 binds persona hints onto inbound
/// frames, the key will migrate to the 8-byte hint. The `peerNodeNum`
/// shape is intentional for P2 because that is all the overlay has
/// available on the wire (the link frame itself does not carry a
/// persona hint yet).
class OverlayCapabilityCoordinator {
  final int Function() _clock;
  final Map<int, OverlayCapabilitySnapshot> _byNodeNum =
      <int, OverlayCapabilitySnapshot>{};
  bool _disposed = false;

  /// Create a new coordinator. Injected [clock] lets tests drive time.
  OverlayCapabilityCoordinator({int Function()? clock})
    : _clock = clock ?? _defaultClock;

  static int _defaultClock() => DateTime.now().millisecondsSinceEpoch;

  /// Record a capability observation for [peerNodeNum].
  ///
  /// Every call overwrites the previous snapshot for that peer; the
  /// freshest observation wins. This matches the locked principle
  /// that capabilities are single-writer-authoritative.
  void record(
    int peerNodeNum,
    OverlayLinkCapabilities capabilities,
    OverlayCapabilityObservationSource source,
  ) {
    if (_disposed) return;
    final snapshot = OverlayCapabilitySnapshot(
      capabilities: capabilities,
      observedAtMs: _clock(),
      source: source,
    );
    final previous = _byNodeNum[peerNodeNum];
    _byNodeNum[peerNodeNum] = snapshot;
    AppLogging.overlay(
      'capability recorded peer=$peerNodeNum '
      'src=${source.name} link=${capabilities.supportsLink} '
      '${previous == null ? "first-seen" : "updated"}',
    );
  }

  /// Return the latest snapshot for [peerNodeNum], or null if none.
  OverlayCapabilitySnapshot? forPeer(int peerNodeNum) =>
      _byNodeNum[peerNodeNum];

  /// True if [peerNodeNum] is known to support MRRP v0.2 link frames.
  bool isLinkCapable(int peerNodeNum) {
    final snapshot = _byNodeNum[peerNodeNum];
    return snapshot != null && snapshot.supportsLink;
  }

  /// Forget [peerNodeNum]'s snapshot. Useful when a peer's link is
  /// closed with a decline-by-policy reason and we want to re-learn.
  void forget(int peerNodeNum) {
    _byNodeNum.remove(peerNodeNum);
  }

  /// Drop every recorded snapshot. Intended for provider disposal.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _byNodeNum.clear();
  }

  /// Diagnostic: how many peers have been observed.
  int get snapshotCount => _byNodeNum.length;

  /// Diagnostic snapshot view (copy; mutations do not flow back).
  Map<int, OverlayCapabilitySnapshot> debugSnapshot() =>
      Map<int, OverlayCapabilitySnapshot>.from(_byNodeNum);
}
