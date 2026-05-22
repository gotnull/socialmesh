// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas immutable model types used by the repository / DAO layer.
// Spec: docs/canvas/CANVAS_V0_1.md. These are pure data classes — no
// protocol, no persistence calls, no side effects.
library;

import 'package:flutter/foundation.dart';

/// Logical scope of a canvas row. Stored as the lowercase enum name in
/// the `canvas.scope` TEXT column.
enum CanvasScope {
  /// Purely-local sandbox. Never broadcast. `canvas_id = 0`.
  local,

  /// Mesh-broadcast canvas bound to a Meshtastic channel.
  mesh,

  /// Reserved for v0.2 event-scoped canvases. Not used in v0.1; do not
  /// create rows with this scope until the event canvas feature lands.
  event,
}

/// Lifecycle status of a canvas. Persisted as INTEGER for compactness.
enum CanvasStatus {
  /// Anyone can paint, all op kinds accepted.
  open,

  /// Cells are visible but no further paints are accepted locally.
  readOnly,

  /// Hidden from the canvas list; not deleted. User can restore.
  archived,
}

/// Outbound queue lifecycle for `pending_op` rows.
enum PendingOpState {
  /// Sitting in the queue, eligible for the next drain pass.
  queued,

  /// Picked up by the send coordinator; not yet confirmed sent.
  inFlight,

  /// Successfully handed to the transport. Repository deletes the row
  /// on this transition; the value is reserved for in-memory state
  /// snapshots only and SHOULD NOT appear as a persisted row.
  sent,

  /// Permanently failed after exhausting the retry schedule. Kept for
  /// 24 h before GC for diagnostics.
  failedTerminal,
}

/// Direction tag for `applied_op` rows.
enum AppliedOpDirection {
  /// Op was received from a peer over the mesh.
  inbound,

  /// Op originated locally (Local Device Canvas paint OR Mesh Canvas
  /// outbound paint).
  outbound,
}

/// Helpers for reading enums back from their persisted integer codes.
abstract final class _EnumStore {
  static T _byIndex<T extends Enum>(List<T> values, int code, String label) {
    if (code < 0 || code >= values.length) {
      throw StateError(
        'Invalid $label code: $code',
      ); // lint-allow: hardcoded-string
    }
    return values[code];
  }

  static CanvasScope scopeFromString(String s) {
    switch (s) {
      case 'local':
        return CanvasScope.local;
      case 'mesh':
        return CanvasScope.mesh;
      case 'event':
        return CanvasScope.event;
    }
    throw StateError('Invalid scope: $s'); // lint-allow: hardcoded-string
  }
}

extension CanvasScopeStorage on CanvasScope {
  String get storageName => name;

  static CanvasScope fromStorage(String s) => _EnumStore.scopeFromString(s);
}

extension CanvasStatusStorage on CanvasStatus {
  int get storageCode => index;

  static CanvasStatus fromStorage(int code) =>
      _EnumStore._byIndex(CanvasStatus.values, code, 'CanvasStatus');
}

extension PendingOpStateStorage on PendingOpState {
  int get storageCode => index;

  static PendingOpState fromStorage(int code) =>
      _EnumStore._byIndex(PendingOpState.values, code, 'PendingOpState');
}

extension AppliedOpDirectionStorage on AppliedOpDirection {
  int get storageCode => index;

  static AppliedOpDirection fromStorage(int code) => _EnumStore._byIndex(
    AppliedOpDirection.values,
    code,
    'AppliedOpDirection',
  );
}

/// One row from the `canvas` table. `localId` is the SQLite
/// AUTOINCREMENT primary key; `canvasId` is the wire-side u64 (or
/// `kLocalCanvasIdSentinel` for purely-local canvases).
@immutable
class CanvasSummary {
  final int localId;
  final int canvasId;
  final CanvasScope scope;
  final int? channelIndex;
  final String name;
  final int width;
  final int height;
  final int paletteId;
  final CanvasStatus status;
  final int? ownerNodeNum;
  final int createdAtMs;
  final int lastOpAtMs;

  /// 16-byte BLAKE2s-128 of canonical state, or null when stale.
  final Uint8List? globalDigest;

  /// 128-byte concatenation of 16 × 8-byte tile digests, or null when no
  /// digest has been computed yet. Individual tile slots may be
  /// zero-filled to indicate per-tile staleness.
  final Uint8List? tileDigests;

  final int cellCount;

  const CanvasSummary({
    required this.localId,
    required this.canvasId,
    required this.scope,
    required this.channelIndex,
    required this.name,
    required this.width,
    required this.height,
    required this.paletteId,
    required this.status,
    required this.ownerNodeNum,
    required this.createdAtMs,
    required this.lastOpAtMs,
    required this.globalDigest,
    required this.tileDigests,
    required this.cellCount,
  });
}

/// One row from the `cell` table. Default-color cells are NOT stored.
@immutable
class CanvasCell {
  final int canvasLocalId;
  final int x;
  final int y;
  final int color;
  final int lastTs;
  final int lastAuthor;
  final int lastSeq;

  const CanvasCell({
    required this.canvasLocalId,
    required this.x,
    required this.y,
    required this.color,
    required this.lastTs,
    required this.lastAuthor,
    required this.lastSeq,
  });
}

/// One row from `pending_op`. Outbound queue tracking only.
@immutable
class PendingCanvasOp {
  final int id;
  final int canvasLocalId;
  final int x;
  final int y;
  final int color;
  final int opTs;
  final int opSeq;
  final int createdAtMs;
  final int attempts;
  final int nextAttemptAtMs;
  final PendingOpState state;
  final String? lastError;

  const PendingCanvasOp({
    required this.id,
    required this.canvasLocalId,
    required this.x,
    required this.y,
    required this.color,
    required this.opTs,
    required this.opSeq,
    required this.createdAtMs,
    required this.attempts,
    required this.nextAttemptAtMs,
    required this.state,
    required this.lastError,
  });
}

/// One row from `applied_op`. Both inbound and outbound ops are recorded.
@immutable
class AppliedCanvasOp {
  final int id;
  final int canvasLocalId;
  final int x;
  final int y;
  final int color;
  final int opTs;
  final int authorNodeNum;
  final int opSeq;
  final AppliedOpDirection direction;
  final int receivedAtMs;
  final bool wasAccepted;

  const AppliedCanvasOp({
    required this.id,
    required this.canvasLocalId,
    required this.x,
    required this.y,
    required this.color,
    required this.opTs,
    required this.authorNodeNum,
    required this.opSeq,
    required this.direction,
    required this.receivedAtMs,
    required this.wasAccepted,
  });
}

/// One row from `peer_digest`. Tracks per-peer canvas state for
/// opportunistic catch-up.
@immutable
class PeerCanvasDigest {
  final int canvasLocalId;
  final int peerNodeNum;
  final Uint8List? peerGlobalDigest;
  final Uint8List? peerTileDigests;
  final int? peerCellCount;
  final int lastHeardAtMs;
  final int? lastSyncAtMs;

  const PeerCanvasDigest({
    required this.canvasLocalId,
    required this.peerNodeNum,
    required this.peerGlobalDigest,
    required this.peerTileDigests,
    required this.peerCellCount,
    required this.lastHeardAtMs,
    required this.lastSyncAtMs,
  });
}
