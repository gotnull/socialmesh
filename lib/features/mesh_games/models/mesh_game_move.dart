// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Wire-safe representation of a single game move.
library;

import 'dart:typed_data';

/// A single accepted move. `data` is game-specific bytes produced by
/// the pure engine's move serializer. The game engine owns semantic
/// interpretation; this model is transport-agnostic.
class MeshGameMove {
  /// Monotonic revision counter assigned when the move is accepted.
  final int revision;

  /// Node number of the player who produced the move.
  final int byNodeNum;

  /// Game-specific payload (rock/paper/scissors ordinal; TTT cell index;
  /// etc). Must fit in `MeshGameType.maxMoveBytes`.
  final Uint8List data;

  /// Wall-clock timestamp when the move was accepted locally.
  final DateTime acceptedAt;

  const MeshGameMove({
    required this.revision,
    required this.byNodeNum,
    required this.data,
    required this.acceptedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'r': revision,
      'by': byNodeNum,
      'd': List<int>.unmodifiable(data),
      't': acceptedAt.millisecondsSinceEpoch,
    };
  }

  factory MeshGameMove.fromJson(Map<String, dynamic> json) {
    final dataList = (json['d'] as List?)?.cast<int>() ?? const <int>[];
    final ts = json['t'] as int?;
    return MeshGameMove(
      revision: (json['r'] as int?) ?? 0,
      byNodeNum: (json['by'] as int?) ?? 0,
      data: Uint8List.fromList(dataList),
      acceptedAt: ts == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }
}
