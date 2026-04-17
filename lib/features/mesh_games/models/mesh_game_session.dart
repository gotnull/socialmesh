// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Durable, hydration-safe wrapper around the game-specific fields of a
/// [MeshServiceInstance.config] map.
///
/// The session is authoritative for UI. The wire protocol (see
/// `docs/mesh_games/MESH_GAMES_V0_1.md`) serializes *subsets* of this
/// model — never the whole thing.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'mesh_game_move.dart';
import 'mesh_game_status.dart';
import 'mesh_game_type.dart';

/// Maximum number of audit moves retained in-session.
const int kMeshGameMoveAuditWindow = 8;

/// Sentinel winner index meaning "no winner" (draw or ongoing).
const int kMeshGameNoWinner = 0xFF;

/// Immutable snapshot of a game session.
///
/// Persistence is handled by wrapping/unwrapping into the `config` JSON
/// of a [MeshServiceInstance]. The engine operates on [stateBlob]
/// directly; UI code uses the higher-level getters.
class MeshGameSession {
  /// Instance ID from the host [MeshServiceInstance].
  final String instanceId;

  /// Game identifier.
  final MeshGameType gameType;

  /// Wire protocol version (currently always 1).
  final int protocolVersion;

  /// Two-element list: `[participants[0], participants[1]]`.
  /// Order is stable; `turnIndex` references this list.
  final List<int> participants;

  /// Node number that initiated the session (first to send `CREATE`).
  final int initiatorNodeNum;

  /// Index into [participants] identifying whose move is expected next.
  /// Meaningless in `rps.v1` (both move simultaneously).
  final int turnIndex;

  /// Monotonic move counter. Increments on every accepted MOVE.
  final int revision;

  /// Wall-clock time of the last accepted move (or CREATE).
  final DateTime lastMoveAt;

  /// Node number of the last mover (or initiator on CREATE).
  final int lastMoveBy;

  /// Current game-level status.
  final MeshGameStatus status;

  /// Winner node number, or null for draw/ongoing.
  final int? winnerNodeNum;

  /// Engine-serialized authoritative state. ≤ `gameType.maxStateBytes`.
  final Uint8List stateBlob;

  /// Recent moves for audit / undo UI. Capped at
  /// [kMeshGameMoveAuditWindow].
  final List<MeshGameMove> moves;

  const MeshGameSession({
    required this.instanceId,
    required this.gameType,
    required this.participants,
    required this.initiatorNodeNum,
    required this.turnIndex,
    required this.revision,
    required this.lastMoveAt,
    required this.lastMoveBy,
    required this.status,
    required this.stateBlob,
    this.protocolVersion = 1,
    this.winnerNodeNum,
    this.moves = const [],
  });

  /// Node number whose move is expected next.
  ///
  /// For RPS (simultaneous commit) the engine may return a placeholder;
  /// callers should rely on engine-specific logic rather than this.
  int? get currentTurnNodeNum {
    if (turnIndex < 0 || turnIndex >= participants.length) return null;
    return participants[turnIndex];
  }

  bool isLocalTurn(int myNodeNum) =>
      status == MeshGameStatus.active && currentTurnNodeNum == myNodeNum;

  bool isLocalParticipant(int myNodeNum) => participants.contains(myNodeNum);

  int? opponentNodeNum(int myNodeNum) {
    for (final p in participants) {
      if (p != myNodeNum) return p;
    }
    return null;
  }

  MeshGameSession copyWith({
    int? turnIndex,
    int? revision,
    DateTime? lastMoveAt,
    int? lastMoveBy,
    MeshGameStatus? status,
    Object? winnerNodeNum = _sentinel,
    Uint8List? stateBlob,
    List<MeshGameMove>? moves,
  }) {
    return MeshGameSession(
      instanceId: instanceId,
      gameType: gameType,
      protocolVersion: protocolVersion,
      participants: participants,
      initiatorNodeNum: initiatorNodeNum,
      turnIndex: turnIndex ?? this.turnIndex,
      revision: revision ?? this.revision,
      lastMoveAt: lastMoveAt ?? this.lastMoveAt,
      lastMoveBy: lastMoveBy ?? this.lastMoveBy,
      status: status ?? this.status,
      winnerNodeNum: identical(winnerNodeNum, _sentinel)
          ? this.winnerNodeNum
          : winnerNodeNum as int?,
      stateBlob: stateBlob ?? this.stateBlob,
      moves: moves ?? this.moves,
    );
  }

  /// Serialize into a [MeshServiceInstance.config] map.
  Map<String, dynamic> toConfig() {
    return {
      'gameType': gameType.identifier,
      'gameTypeCode': gameType.code,
      'protocolVersion': protocolVersion,
      'participants': List<int>.unmodifiable(participants),
      'initiatorNodeNum': initiatorNodeNum,
      'turnIndex': turnIndex,
      'revision': revision,
      'lastMoveAt': lastMoveAt.millisecondsSinceEpoch,
      'lastMoveBy': lastMoveBy,
      'gameStatusCode': status.code,
      'gameWinnerIndex': _winnerIndex(),
      'winnerNodeNum': winnerNodeNum,
      'stateBlob': base64Encode(stateBlob),
      'moves': moves.map((m) => m.toJson()).toList(growable: false),
    };
  }

  int _winnerIndex() {
    if (winnerNodeNum == null) return kMeshGameNoWinner;
    final idx = participants.indexOf(winnerNodeNum!);
    return idx < 0 ? kMeshGameNoWinner : idx;
  }

  static MeshGameSession? tryFromConfig({
    required String instanceId,
    required Map<String, dynamic> config,
  }) {
    final typeId = config['gameType'];
    final gameType = typeId is String
        ? MeshGameType.fromIdentifier(typeId)
        : null;
    if (gameType == null) return null;

    final participantsRaw = config['participants'];
    final participants = participantsRaw is List
        ? List<int>.from(participantsRaw.whereType<int>())
        : const <int>[];
    if (participants.length != 2) return null;

    final stateRaw = config['stateBlob'];
    Uint8List stateBlob;
    if (stateRaw is String) {
      try {
        stateBlob = Uint8List.fromList(base64Decode(stateRaw));
      } catch (_) {
        return null;
      }
    } else if (stateRaw is List<int>) {
      stateBlob = Uint8List.fromList(stateRaw);
    } else {
      stateBlob = Uint8List(0);
    }

    final movesRaw = config['moves'];
    final moves = movesRaw is List
        ? movesRaw
              .whereType<Map>()
              .map((m) => MeshGameMove.fromJson(Map<String, dynamic>.from(m)))
              .toList(growable: false)
        : const <MeshGameMove>[];

    return MeshGameSession(
      instanceId: instanceId,
      gameType: gameType,
      protocolVersion: (config['protocolVersion'] as int?) ?? 1,
      participants: List.unmodifiable(participants),
      initiatorNodeNum:
          (config['initiatorNodeNum'] as int?) ?? participants.first,
      turnIndex: (config['turnIndex'] as int?) ?? 0,
      revision: (config['revision'] as int?) ?? 0,
      lastMoveAt: DateTime.fromMillisecondsSinceEpoch(
        (config['lastMoveAt'] as int?) ?? 0,
      ),
      lastMoveBy:
          (config['lastMoveBy'] as int?) ??
          (config['initiatorNodeNum'] as int?) ??
          participants.first,
      status:
          MeshGameStatus.fromCode(
            (config['gameStatusCode'] as int?) ?? MeshGameStatus.active.code,
          ) ??
          MeshGameStatus.active,
      winnerNodeNum: config['winnerNodeNum'] as int?,
      stateBlob: stateBlob,
      moves: moves,
    );
  }
}

const Object _sentinel = Object();
