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

  /// Bumped to 2 for the v0.1 board-size reduction (128×128 → 64×64).
  /// The wire format changes (canvas_digest 160B → 64B, tile_digests
  /// 128B → 32B, tile range 0..3 → 0..1) make any prior `cell` rows
  /// painted at coordinates ≥ 64 invalid for the new geometry, and
  /// any cached digest blob the wrong size. The onUpgrade handler
  /// drops every canvas table row; users opening a previously-used
  /// build wake to a fresh canvas state — the protocol then
  /// re-hydrates from peers via digest sync. This is acceptable per
  /// the v0.1 board-size-reduction directive ("safe to wipe").
  static const int dbVersion = 2;
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
///
/// v0.1 launch dimensions: 64 × 64 cells, 2 × 2 tiles of 32 × 32 each.
/// The original draft used 128 × 128 / 16 tiles, but real-hardware
/// hydration tests showed the larger surface produced sparse,
/// emotionally inactive boards under typical 2-20 user densities.
/// 64 × 64 quadruples observed paint density at the same cell count
/// (e.g., 316 cells → ~7.7 % occupancy vs ~1.9 %) and cuts the worst-
/// case sync workload from 16 tiles to 4 — fewer mismatched tiles per
/// digest cycle, fewer sync_requests, faster hydration on first run,
/// less governor pressure, denser visible activity. Tile size stays
/// 32 × 32 so the RLE / raw-band coordinate math, governor sizing,
/// and codec byte layouts remain dimension-derived through these
/// constants.
abstract final class CanvasGeometry {
  /// Width of every canvas in cells.
  static const int width = 64;

  /// Height of every canvas in cells.
  static const int height = 64;

  /// Side length of a tile in cells (32 × 32). Unchanged across the
  /// 128→64 resize so RLE/raw-band encoding stays valid as-is.
  static const int tileSize = 32;

  /// Number of tiles per row across the canvas (64 / 32 = 2).
  static const int tilesPerRow = 2;

  /// Total number of tiles per canvas (2 × 2 = 4).
  static const int tileCount = 4;
}

/// Digest sizes per CANVAS_V0_1.md §6.3 + §7.
abstract final class CanvasDigestSizes {
  /// BLAKE2s-128 global digest length in bytes.
  static const int globalBytes = 16;

  /// Truncated per-tile digest length in bytes (BLAKE2s-128 → 8).
  static const int tileBytes = 8;

  /// Concatenated tile digests length:
  ///   v0.1 64×64 → 4 tiles × 8 bytes = 32.
  ///   (Was 16 × 8 = 128 during the 128×128 draft.)
  static const int tilesConcatenatedBytes =
      CanvasGeometry.tileCount * tileBytes;

  /// Total canvas_digest payload length in bytes:
  ///   12 (common prefix) + 16 (global) + 4 (cellCount) +
  ///   tilesConcatenatedBytes (per-tile blob).
  ///   v0.1 64×64 → 64 bytes. (Was 160 during the 128×128 draft.)
  /// The codec slices and ByteData allocations derive from this so
  /// future geometry changes only require updating CanvasGeometry.
  static const int totalDigestPayloadBytes = 32 + tilesConcatenatedBytes;
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

/// Mesh-canvas paint-cadence pacing. Tap-layer scarcity that makes
/// every mesh pixel feel deliberate instead of confetti spray.
/// Applies ONLY to mesh-scope canvases; the Local Device Canvas
/// stays unmetered (it never broadcasts and never enqueues).
abstract final class CanvasCadence {
  /// Minimum interval between accepted mesh paint taps on a given
  /// canvas. Below this window the tap is silently rejected: no
  /// `pending_op` row is enqueued and the local `cell` is NOT
  /// mutated. The HUD surfaces this as a `cooling` severity so the
  /// user sees airtime pressure, not punishment.
  ///
  /// 2.5 s = once every ~24 paints per minute per user per canvas,
  /// well below the 21-op paint_batch cap and the 250 B/min canvas
  /// governor. Tunable here without touching wire formats.
  static const Duration meshTapInterval = Duration(milliseconds: 2500);
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
