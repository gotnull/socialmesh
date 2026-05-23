// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas persistence constants — schema names, geometry, validation
// bounds, retention windows. Sourced from docs/canvas/CANVAS_V0_1.md.
// Bumping any value here is a wire/schema change that MUST come with a
// matching spec revision and a database migration.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// canvas.db filename + current schema version.
abstract final class CanvasDbConfig {
  static const String dbName = 'canvas.db';
  static const int dbVersion = 1;
}

/// SQLite table names for the canvas persistence layer.
abstract final class CanvasTables {
  static const String canvas = 'canvas';
  static const String cell = 'cell';
  static const String pendingOp = 'pending_op';
  static const String appliedOp = 'applied_op';
  static const String peerDigest = 'peer_digest';
}

/// Canvas geometry per CANVAS_V0_1.md §6.3. Changing any of these is a
/// wire-format break and requires a new canvas.v? spec.
abstract final class CanvasGeometry {
  /// Width of every canvas in cells.
  static const int width = 128;

  /// Height of every canvas in cells.
  static const int height = 128;

  /// Side length of a tile in cells (32 × 32).
  static const int tileSize = 32;

  /// Number of tiles per row across the canvas (128 / 32 = 4).
  static const int tilesPerRow = 4;

  /// Total number of tiles per canvas (4 × 4 = 16).
  static const int tileCount = 16;
}

/// Digest sizes per CANVAS_V0_1.md §6.3 + §7.
abstract final class CanvasDigestSizes {
  /// BLAKE2s-128 global digest length in bytes.
  static const int globalBytes = 16;

  /// Truncated per-tile digest length in bytes (BLAKE2s-128 → 8).
  static const int tileBytes = 8;

  /// Concatenated tile digests length: 16 tiles × 8 bytes = 128.
  static const int tilesConcatenatedBytes =
      CanvasGeometry.tileCount * tileBytes;
}

/// Validation bounds enforced by the repository layer before any DB write.
abstract final class CanvasLimits {
  /// Maximum legal `x` or `y` cell coordinate (inclusive). Cells 0..127.
  static const int cellCoordMax = CanvasGeometry.width - 1;

  /// Maximum legal palette index. Indices 0..63 fit in the low 6 bits of
  /// the wire byte; the top 2 bits are reserved per CANVAS_V0_1.md §11.
  static const int colorMax = 63;

  /// Maximum legal Meshtastic channel index (0..7).
  static const int channelIndexMax = 7;

  /// Maximum UTF-8 byte length of a canvas name as stored locally.
  /// Wire `name_hint` in `canvas_info` is bounded at 8 bytes
  /// (CANVAS_V0_1.md §6.6); local storage allows up to 32 for the full
  /// user-facing name.
  static const int canvasNameMaxBytes = 32;

  /// Per-canvas pending outbound queue cap. When this many ops are queued
  /// for a canvas, the oldest queued rows are dropped (cell state is
  /// already in `cell`; peers catch up via digest sync). See
  /// CANVAS_V0_1.md §9 + the v0.1 plan §5.
  static const int pendingQueueCap = 256;

  /// op_seq wraps mod-256.
  static const int opSeqModulus = 256;
}

/// Presence frame constraints per CANVAS_PRESENCE_V0_1.md §2.2 / §3.1.
/// These bounds are wire-pinned: receivers MUST reject any presence
/// frame whose `ttl_seconds` falls outside the inclusive [min, max]
/// window. The default value is what the local emitter writes for
/// every outgoing heartbeat (2x the 90s heartbeat cadence so one
/// missed beat is tolerated before expiry).
abstract final class CanvasPresenceLimits {
  /// Minimum permitted `ttl_seconds` (inclusive). Receivers drop below.
  static const int ttlSecondsMin = 60;

  /// Maximum permitted `ttl_seconds` (inclusive). Receivers drop above.
  static const int ttlSecondsMax = 600;

  /// Default `ttl_seconds` emitted by the local heartbeat. Twice the
  /// 90s refresh window so one missed heartbeat is tolerated before
  /// the entry expires on a peer.
  static const int ttlSecondsDefault = 180;
}

/// Retention windows for periodic GC. Repository exposes prune helpers
/// that callers invoke from a background tick (S9 schedules it).
abstract final class CanvasRetention {
  /// Applied op log retention. See plan §5 `applied_op`.
  static const Duration appliedOpAge = Duration(days: 30);

  /// Peer digest tracking retention. See plan §5 `peer_digest`.
  static const Duration peerDigestAge = Duration(days: 7);
}

/// Default palette identifier shipped with v0.1. Wire-rejected by
/// receivers when `palette_id != 1`, per CANVAS_V0_1.md §11 / I4.
const int kCanvasDefaultPaletteId = 1;

/// Default canvas dimensions exposed by `canvas` rows in v0.1.
const int kCanvasDefaultWidth = CanvasGeometry.width;
const int kCanvasDefaultHeight = CanvasGeometry.height;

/// `canvas_id` value reserved for purely-local canvases (Local Device
/// Canvas). Never serialized to the wire.
const int kLocalCanvasIdSentinel = 0;

/// Convert a cell `(x, y)` to its tile index in `tile_digests[0..15]`.
/// Layout is row-major across 4 tile columns: `tile_idx = (y/32)*4 + (x/32)`.
int canvasTileIndexForCell(int x, int y) =>
    (y ~/ CanvasGeometry.tileSize) * CanvasGeometry.tilesPerRow +
    (x ~/ CanvasGeometry.tileSize);

/// Derive the canonical `canvas_id` for a Meshtastic channel canvas.
///
/// Wire contract (CANVAS_V0_1.md §3):
///
/// ```
/// canvas_id = first 8 bytes (little-endian u64) of
///             SHA-256(channel_psk_bytes_or_empty || canvas_name_utf8)
/// ```
///
/// `channelPsk` may be empty (default-keyed channel) — the SHA-256 input
/// just becomes the UTF-8 name in that case. The function is pure: two
/// devices with the same `(psk, name)` always derive the same id, which
/// is what makes channel-bound canvases converge without negotiation.
///
/// Returned as a Dart `int`. SQLite's INTEGER column is a 64-bit signed
/// type, so values with the high bit set arrive in storage as negative
/// numbers; that is fine — the canvas table never reasons about sign,
/// only equality.
int deriveCanvasIdFromChannel({
  required List<int> channelPsk,
  required String canvasName,
}) {
  final input = BytesBuilder()
    ..add(channelPsk)
    ..add(utf8.encode(canvasName));
  final digest = sha256.convert(input.toBytes());
  // First 8 bytes as little-endian u64.
  var id = 0;
  for (var i = 0; i < 8; i++) {
    id |= (digest.bytes[i] & 0xff) << (i * 8);
  }
  return id;
}
