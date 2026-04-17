// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Game-level lifecycle state. Distinct from `MeshServiceStatus`, which
/// tracks the persistence row's active/stopped/expired state.
library;

/// Current state of a mesh game session.
///
/// Values are frozen on the wire — transmitted as a single byte in
/// `STATE_RESP`. See `docs/mesh_games/MESH_GAMES_V0_1.md` § 5.1.
enum MeshGameStatus {
  /// Session is in progress. Either player's turn may be expected.
  active(0x01),

  /// Session ended with a winner or draw. Terminal.
  completed(0x02),

  /// Session was voluntarily quit or reached an abandon timeout.
  /// Terminal.
  abandoned(0x03),

  /// Local state has drifted from peer state; UI should offer resync.
  /// Non-terminal — returns to [active] on successful `STATE_RESP`.
  stale(0x04);

  const MeshGameStatus(this.code);

  final int code;

  bool get isTerminal =>
      this == MeshGameStatus.completed || this == MeshGameStatus.abandoned;

  static MeshGameStatus? fromCode(int code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return null;
  }

  /// Deserialize from `service_instances.config.status` string value.
  static MeshGameStatus fromStorage(Object? value) {
    if (value is String) {
      for (final status in values) {
        if (status.name == value) return status;
      }
    }
    return MeshGameStatus.active;
  }
}

/// Reason byte transmitted with a `QUIT` opcode.
enum MeshGameQuitReason {
  voluntary(0x00),
  timeout(0x01),
  error(0x02);

  const MeshGameQuitReason(this.code);

  final int code;

  static MeshGameQuitReason? fromCode(int code) {
    for (final r in values) {
      if (r.code == code) return r;
    }
    return null;
  }
}
