// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Data models for the SPP v0.2 resource layer (P4).
///
/// The wire codec lives in `overlay_resource_codec.dart` (P0). The
/// state-machine enum lives in `overlay_types.dart` (P0). This file
/// adds the persistence model — the record shape we keep in
/// `overlay_transfers.db` — and the event types the engine publishes.
///
/// Per the P4 locked principle: resources bind **primarily to the
/// stable peer endpoint identity**, with `linkId` as an advisory
/// current-session-context hint. Links expire; resources may need to
/// resume across link turnover.
library;

import 'dart:typed_data';

import 'overlay_types.dart';

/// Which side of a transfer this node plays for a given record.
enum OverlayResourceRole {
  /// Local side advertised the resource (sent OFFER).
  sender(0),

  /// Local side received an OFFER and accepted it.
  receiver(1);

  const OverlayResourceRole(this.code);

  /// Wire / DB code.
  final int code;

  /// Resolve a code to a role, or null if unknown.
  static OverlayResourceRole? fromCode(int code) {
    for (final r in values) {
      if (r.code == code) return r;
    }
    return null;
  }
}

/// Immutable row of `overlay_transfers.db` — one per active or
/// recently-terminal transfer.
///
/// Composite primary key: `(peer_endpoint_hint, resource_id)`. This
/// mirrors the semantics the spec §11.5 describes — a record is
/// scoped to the peer you're talking to. The engine never tries to
/// merge records across peers.
class OverlayResourceRecord {
  /// 4-byte sender-assigned resource identifier (wire: §11.2).
  final int resourceId;

  /// 8-byte persona hint of the peer (stable identity). For sender
  /// records, this is the receiver; for receiver records, the sender.
  final Uint8List peerEndpointHint;

  /// Meshtastic node num of the peer. Ephemeral hint only — not a
  /// truth key. The engine refreshes this opportunistically.
  final int peerNodeNum;

  /// 4-byte link id the transfer is currently riding, or null if the
  /// link is gone. Resources survive link turnover; this column is
  /// advisory "current session context" only.
  final int? linkId;

  /// Which side local is playing.
  final OverlayResourceRole role;

  /// Lifecycle state.
  final OverlayResourceState state;

  /// Total payload byte count (as advertised in OFFER).
  final int totalBytes;

  /// Wire chunk size (bytes). Fixed at OFFER time; receiver is
  /// entitled to reject if it exceeds its declared ceiling.
  final int chunkSize;

  /// `ceil(totalBytes / chunkSize)`. Fits in u16 per spec §11.3.
  final int chunkCount;

  /// Complete-integrity SHA-256 (32 bytes). On the sender side, set
  /// at OFFER creation. On the receiver side, set once a `COMPLETE`
  /// frame arrives (before verification).
  final Uint8List? sha256;

  /// Optional MIME type.
  final String? mimeType;

  /// Optional original filename.
  final String? filename;

  /// Packed bitmap of received chunks (`ceil(chunkCount / 8)` bytes).
  /// Sender-side: tracks which chunks the receiver has acknowledged
  /// via BITMAP. Receiver-side: tracks which chunks it has written
  /// to `overlay_transfer_chunks`.
  final Uint8List bitmap;

  /// Wall-clock ms when the row was created.
  final int createdAtMs;

  /// Wall-clock ms of the last valid frame in either direction.
  final int lastActivityMs;

  /// Wall-clock ms at which the row expires and must be closed with
  /// `timeout`. Derived from `createdAtMs +
  /// OverlayResourceConstants.partialRetentionSec` for in-progress,
  /// extended to `completeMetaRetentionSec` once terminal.
  final int expiresAtMs;

  /// Number of RESUME / retransmission attempts observed.
  final int retryCount;

  /// Close reason once [state] is terminal. Reuses
  /// [OverlayLinkCloseReason] for consistency with link-layer events.
  final OverlayLinkCloseReason? closeReason;

  /// Wall-clock ms when the terminal transition occurred.
  final int? closedAtMs;

  const OverlayResourceRecord({
    required this.resourceId,
    required this.peerEndpointHint,
    required this.peerNodeNum,
    this.linkId,
    required this.role,
    required this.state,
    required this.totalBytes,
    required this.chunkSize,
    required this.chunkCount,
    this.sha256,
    this.mimeType,
    this.filename,
    required this.bitmap,
    required this.createdAtMs,
    required this.lastActivityMs,
    required this.expiresAtMs,
    required this.retryCount,
    this.closeReason,
    this.closedAtMs,
  });

  /// Return a copy with selected fields replaced.
  OverlayResourceRecord copyWith({
    int? peerNodeNum,
    int? linkId,
    OverlayResourceState? state,
    Uint8List? sha256,
    Uint8List? bitmap,
    int? lastActivityMs,
    int? expiresAtMs,
    int? retryCount,
    OverlayLinkCloseReason? closeReason,
    int? closedAtMs,
  }) {
    return OverlayResourceRecord(
      resourceId: resourceId,
      peerEndpointHint: peerEndpointHint,
      peerNodeNum: peerNodeNum ?? this.peerNodeNum,
      linkId: linkId ?? this.linkId,
      role: role,
      state: state ?? this.state,
      totalBytes: totalBytes,
      chunkSize: chunkSize,
      chunkCount: chunkCount,
      sha256: sha256 ?? this.sha256,
      mimeType: mimeType,
      filename: filename,
      bitmap: bitmap ?? this.bitmap,
      createdAtMs: createdAtMs,
      lastActivityMs: lastActivityMs ?? this.lastActivityMs,
      expiresAtMs: expiresAtMs ?? this.expiresAtMs,
      retryCount: retryCount ?? this.retryCount,
      closeReason: closeReason ?? this.closeReason,
      closedAtMs: closedAtMs ?? this.closedAtMs,
    );
  }

  /// True if [state] is a terminal condition.
  bool get isTerminal {
    switch (state) {
      case OverlayResourceState.complete:
      case OverlayResourceState.failed:
      case OverlayResourceState.cancelled:
      case OverlayResourceState.declined:
      case OverlayResourceState.corrupt:
        return true;
      case OverlayResourceState.idle:
      case OverlayResourceState.offering:
      case OverlayResourceState.negotiating:
      case OverlayResourceState.transferring:
      case OverlayResourceState.awaitingVerify:
      case OverlayResourceState.evaluating:
      case OverlayResourceState.accepting:
      case OverlayResourceState.receiving:
      case OverlayResourceState.verifying:
        return false;
    }
  }

  /// True if [state] is one the engine may resume from on startup.
  /// Matches spec §11.8 — only `receiving` (receiver) and
  /// `transferring` (sender) qualify; everything else either is
  /// terminal or was in a mid-handshake state that cannot safely
  /// resume mid-flight.
  bool get isResumable =>
      state == OverlayResourceState.receiving ||
      state == OverlayResourceState.transferring;

  @override
  String toString() =>
      'OverlayResourceRecord('
      'resourceId=0x${resourceId.toRadixString(16).padLeft(8, '0')}, '
      'role=${role.name}, state=${state.name}, '
      'chunks=$chunkCount, peer=$peerNodeNum, linkId='
      '${linkId == null ? 'null' : '0x${linkId!.toRadixString(16)}'})';
}

/// Event kinds published by `OverlayResourceEngine` on its stream.
enum OverlayResourceEventKind {
  /// A new transfer row was created (local OFFER or remote OFFER).
  offered,

  /// A receiver's ACCEPT was processed (by either side).
  accepted,

  /// A receiver's DECLINE was processed (by either side).
  declined,

  /// A CHUNK was written (receiver) or sent (sender).
  chunkStored,

  /// A BITMAP or NACK was received/sent; window progress observed.
  bitmapObserved,

  /// `COMPLETE` received/sent and the hash is being verified.
  completing,

  /// Integrity verified and the transfer is complete.
  complete,

  /// Terminal: `failed` / `corrupt` / `cancelled` / `declined`.
  terminated,

  /// Row restored from DB (mid-transfer → same state, not resurrected).
  restored,
}

/// An event emitted by `OverlayResourceEngine`.
class OverlayResourceEvent {
  /// What happened.
  final OverlayResourceEventKind kind;

  /// The post-transition record.
  final OverlayResourceRecord record;

  /// Free-form diagnostic reason.
  final String? detail;

  const OverlayResourceEvent({
    required this.kind,
    required this.record,
    this.detail,
  });
}
