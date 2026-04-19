// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Data models carried by `OverlayLinkStore` and `OverlayLinkEngine`.
///
/// See `docs/sip/OVERLAY_V0_2.md` §10 and §13.1 for the wire-level and
/// persistence definitions these models mirror.
library;

import 'dart:typed_data';

import 'overlay_types.dart';

/// Negotiated per-link capability snapshot.
///
/// Captured at link-open time from the peer's capability block (§16.1)
/// and persisted with the link row. If a peer restarts and its
/// advertised capabilities change, the new values apply only to a new
/// link — existing links keep their snapshot until closed.
class OverlayLinkCapabilities {
  /// Bitset of [OverlayCapabilityFeature] bits the peer advertises.
  final int supportedFeatures;

  /// Peer-advertised chunk payload ceiling, or null if not advertised.
  final int? maxChunkBytes;

  /// Peer-advertised resource size ceiling, or null if not advertised.
  final int? maxResourceBytes;

  const OverlayLinkCapabilities({
    required this.supportedFeatures,
    this.maxChunkBytes,
    this.maxResourceBytes,
  });

  /// The empty capability set.
  static const OverlayLinkCapabilities none = OverlayLinkCapabilities(
    supportedFeatures: 0,
  );

  /// Peer supports v0.2 link frames.
  bool get supportsLink =>
      (supportedFeatures & OverlayCapabilityFeature.linkV02) != 0;

  /// Peer supports v0.2 resource transfer.
  bool get supportsResource =>
      (supportedFeatures & OverlayCapabilityFeature.resourceV02) != 0;

  @override
  String toString() =>
      'OverlayLinkCapabilities(features=0x'
      '${supportedFeatures.toRadixString(16)}, '
      'maxChunk=$maxChunkBytes, maxResource=$maxResourceBytes)';
}

/// A durable link record stored in `links.db`.
///
/// Immutable. Mutations go through [OverlayLinkEngine], which emits a
/// new record on each transition. See §13.1 for the schema.
class OverlayLinkRecord {
  /// 4-byte link identifier (wire: §9.3).
  final int linkId;

  /// 8-byte persona hint of the peer (matches SIP `SENDER_PUBKEY_HINT`).
  final Uint8List peerPersonaHint;

  /// Meshtastic node num of the peer. Used only for egress routing —
  /// not part of the overlay identity model.
  final int peerNodeNum;

  /// Current lifecycle state.
  final OverlayLinkState state;

  /// True if this node initiated the link; false if it was the
  /// responder.
  final bool isInitiator;

  /// Negotiated capabilities snapshot.
  final OverlayLinkCapabilities capabilities;

  /// Wall-clock ms when the link row was first created.
  final int openedAtMs;

  /// Wall-clock ms of the most recent valid frame in either direction.
  final int lastActivityMs;

  /// Wall-clock ms at which this record expires and must be closed
  /// with `timeout`. Derived from `openedAtMs +
  /// OverlayLinkConstants.linkMaxLifetimeSec`.
  final int expiresAtMs;

  /// Next 16-bit `seq` to assign on an outbound frame.
  final int txNextSeq;

  /// Highest 16-bit `seq` the peer has cumulatively acknowledged.
  final int txAckHi;

  /// Next 16-bit `seq` we expect on an inbound frame. Frames with a
  /// different seq are dropped as duplicates or out-of-order (P1 is
  /// strictly in-order; selective retransmission lands in P5).
  final int rxExpectedSeq;

  /// Number of retry attempts observed for the current transition.
  /// Reset to zero when the link reaches `active`.
  final int retryCount;

  /// Close reason, once [state] is `closed` or `failed`. `null`
  /// otherwise.
  final OverlayLinkCloseReason? closeReason;

  /// Wall-clock ms when the close transition occurred, or null.
  final int? closedAtMs;

  const OverlayLinkRecord({
    required this.linkId,
    required this.peerPersonaHint,
    required this.peerNodeNum,
    required this.state,
    required this.isInitiator,
    required this.capabilities,
    required this.openedAtMs,
    required this.lastActivityMs,
    required this.expiresAtMs,
    required this.txNextSeq,
    required this.txAckHi,
    required this.rxExpectedSeq,
    required this.retryCount,
    this.closeReason,
    this.closedAtMs,
  });

  /// Return a copy with selected fields replaced.
  OverlayLinkRecord copyWith({
    OverlayLinkState? state,
    int? lastActivityMs,
    int? txNextSeq,
    int? txAckHi,
    int? rxExpectedSeq,
    int? retryCount,
    OverlayLinkCloseReason? closeReason,
    int? closedAtMs,
    OverlayLinkCapabilities? capabilities,
    int? expiresAtMs,
  }) {
    return OverlayLinkRecord(
      linkId: linkId,
      peerPersonaHint: peerPersonaHint,
      peerNodeNum: peerNodeNum,
      state: state ?? this.state,
      isInitiator: isInitiator,
      capabilities: capabilities ?? this.capabilities,
      openedAtMs: openedAtMs,
      lastActivityMs: lastActivityMs ?? this.lastActivityMs,
      expiresAtMs: expiresAtMs ?? this.expiresAtMs,
      txNextSeq: txNextSeq ?? this.txNextSeq,
      txAckHi: txAckHi ?? this.txAckHi,
      rxExpectedSeq: rxExpectedSeq ?? this.rxExpectedSeq,
      retryCount: retryCount ?? this.retryCount,
      closeReason: closeReason ?? this.closeReason,
      closedAtMs: closedAtMs ?? this.closedAtMs,
    );
  }

  /// True if [state] represents a terminal condition.
  bool get isTerminal =>
      state == OverlayLinkState.closed || state == OverlayLinkState.failed;

  @override
  String toString() =>
      'OverlayLinkRecord('
      'linkId=0x${linkId.toRadixString(16).padLeft(8, '0')}, '
      'state=${state.name}, peer=$peerNodeNum, '
      'tx=$txNextSeq/ackHi=$txAckHi, rx=$rxExpectedSeq)';
}

/// Event kinds published by [OverlayLinkEngine] on its events stream.
enum OverlayLinkEventKind {
  /// A new link row was created (either local open or remote request).
  opened,

  /// The link transitioned into `active` and is available for data.
  activated,

  /// The link transitioned into `stale` due to inactivity.
  staled,

  /// The link entered a terminal state (`closed` or `failed`).
  terminated,

  /// An inbound `LINK_DATA` frame passed dedupe and was delivered to
  /// the consumer.
  dataDelivered,

  /// An inbound frame was dropped by the dedupe / seq-ordering layer.
  dataDropped,

  /// An inbound `LINK_OPEN` was rejected by policy.
  rejected,

  /// The record was restored from `links.db` at startup with a
  /// downgraded state (per the no-phantom-open rule).
  restored,
}

/// An event emitted by [OverlayLinkEngine].
///
/// Consumers subscribe via `OverlayLinkEngine.events` to observe link
/// lifecycle transitions, data delivery, and dedupe drops.
class OverlayLinkEvent {
  /// What happened.
  final OverlayLinkEventKind kind;

  /// The post-transition record.
  final OverlayLinkRecord record;

  /// Payload bytes for [OverlayLinkEventKind.dataDelivered]; null
  /// otherwise. Held by reference — consumers must not mutate.
  final Uint8List? payload;

  /// A short diagnostic reason — used for drops and restores.
  final String? detail;

  const OverlayLinkEvent({
    required this.kind,
    required this.record,
    this.payload,
    this.detail,
  });
}

/// Policy callback invoked when a peer initiates a link via
/// `LINK_OPEN`.
///
/// Return `null` to accept, or an [OverlayLinkCloseReason] to decline
/// with that reason. Must be pure and synchronous — the engine holds
/// its mutation lock while calling.
typedef OverlayLinkAcceptPolicy =
    OverlayLinkCloseReason? Function(OverlayLinkRecord incoming);

/// Default accept policy: accept every inbound LINK_OPEN. Suitable for
/// unit tests only. Production callers MUST supply a stricter policy
/// (e.g., capacity cap, peer trust check) when wiring in P2.
OverlayLinkCloseReason? overlayLinkAcceptAll(OverlayLinkRecord incoming) =>
    null;
