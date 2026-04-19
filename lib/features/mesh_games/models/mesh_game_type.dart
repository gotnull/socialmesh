// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Mesh game type registry. See `docs/mesh_games/MESH_GAMES_V0_1.md`.
library;

/// Wire-frozen identifiers for the Slice 1 games.
///
/// The wire `code` is the single byte used in `CREATE` frames and in
/// `service_instances.config.gameTypeCode`. Codes are one-way — never
/// reuse a code for a different game, and never rename the identifier
/// string in a new version (bump the version suffix instead).
enum MeshGameType {
  rpsV1(code: 0x01, identifier: 'rps.v1', maxStateBytes: 8, maxMoveBytes: 1),
  ticTacToeV1(
    code: 0x02,
    identifier: 'tic_tac_toe.v1',
    maxStateBytes: 16,
    maxMoveBytes: 1,
  );

  const MeshGameType({
    required this.code,
    required this.identifier,
    required this.maxStateBytes,
    required this.maxMoveBytes,
  });

  /// One-byte wire code.
  final int code;

  /// Stable string identifier (stored in `config.gameType`).
  final String identifier;

  /// Maximum serialized state size; budget check at codec layer.
  final int maxStateBytes;

  /// Maximum serialized move size.
  final int maxMoveBytes;

  static MeshGameType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }

  static MeshGameType? fromIdentifier(String identifier) {
    for (final type in values) {
      if (type.identifier == identifier) return type;
    }
    return null;
  }
}
