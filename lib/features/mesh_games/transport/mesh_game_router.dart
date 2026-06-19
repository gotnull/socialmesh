// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Inbound mesh-game dispatch.
///
/// Called by [MeshServiceEngine.handleInteraction] when an MRRP
/// `interact` targets a game-canonical instance. Decodes the wire
/// frame, applies the pure engine, persists, and returns a minimal
/// ack payload per the spec § 6.1.
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import '../../../services/protocol/sip/mrrp_types.dart';
import '../../mesh_services/models/mesh_service_instance.dart';
import '../data/mesh_game_rate_limiter.dart';
import '../data/mesh_game_repository.dart';
import '../engine/game_engine.dart';
import '../engine/game_engine_registry.dart';
import '../models/mesh_game_move.dart';
import '../models/mesh_game_session.dart';
import '../models/mesh_game_status.dart';
import 'mesh_game_codec.dart';

/// Result returned by the router. `ackPayload` is the bytes sent back
/// in the MRRP response; `statusCode` is pushed into the
/// `MrrpStatusCode` TLV by the caller (as the engine does today).
class MeshGameRouterResult {
  final Uint8List ackPayload;
  final MrrpStatusCode statusCode;

  const MeshGameRouterResult({
    required this.ackPayload,
    required this.statusCode,
  });

  static MeshGameRouterResult ok([Uint8List? body]) => MeshGameRouterResult(
    ackPayload: body ?? Uint8List(0),
    statusCode: MrrpStatusCode.ok,
  );

  static MeshGameRouterResult error(MrrpStatusCode code) =>
      MeshGameRouterResult(
        ackPayload: Uint8List.fromList([code.code]),
        statusCode: code,
      );
}

/// Inbound mesh-games handler.
///
/// Callbacks are used (instead of direct providers) so this layer
/// stays pure and testable.
class MeshGameRouter {
  final MeshGameRepository _repo;
  final MeshGameRateLimiter _rateLimiter;
  final VoidCallback _onSessionChanged;

  MeshGameRouter({
    required MeshGameRepository repository,
    required this._rateLimiter,
    VoidCallback? onSessionChanged,
  }) : _repo = repository,
       _onSessionChanged = onSessionChanged ?? _noop;

  /// Entry point called from [MeshServiceEngine.handleInteraction].
  ///
  /// Returns the inner MRRP response payload (not including the magic
  /// instance-ID prefix, which the engine does not apply to interact
  /// responses).
  Future<Uint8List?> handle(
    MeshServiceInstance instance,
    int senderNodeId,
    Uint8List innerPayload,
  ) async {
    if (!_rateLimiter.tryAcquire(senderNodeId)) {
      AppLogging.meshGameTransport(
        'rate-limited sender=0x${senderNodeId.toRadixString(16)} '
        'instance=${instance.instanceId}',
      );
      return MeshGameRouterResult.error(MrrpStatusCode.rateLimited).ackPayload;
    }

    final MeshGameFrame frame;
    try {
      frame = MeshGameCodec.decode(innerPayload);
    } on FormatException catch (e) {
      AppLogging.meshGameTransport(
        'decode rejected instance=${instance.instanceId} reason=$e',
      );
      return MeshGameRouterResult.error(MrrpStatusCode.invalid).ackPayload;
    }

    AppLogging.meshGameTransport(
      'recv op=${frame.opcode.name} sender=0x${senderNodeId.toRadixString(16)} '
      'instance=${instance.instanceId}',
    );

    final existing = await _repo.loadSession(instance.instanceId);

    switch (frame.opcode) {
      case MeshGameOpcode.create:
        return _handleCreate(instance, senderNodeId, frame, existing);
      case MeshGameOpcode.join:
        return _handleJoin(instance, senderNodeId, frame, existing);
      case MeshGameOpcode.move:
        return _handleMove(instance, senderNodeId, frame, existing);
      case MeshGameOpcode.stateReq:
        return _handleStateReq(instance, senderNodeId, existing);
      case MeshGameOpcode.stateResp:
        return _handleStateResp(instance, senderNodeId, frame, existing);
      case MeshGameOpcode.quit:
        return _handleQuit(instance, senderNodeId, frame, existing);
    }
  }

  Future<Uint8List?> _handleCreate(
    MeshServiceInstance instance,
    int senderNodeId,
    MeshGameFrame frame,
    MeshGameSession? existing,
  ) async {
    if (existing != null) {
      // CREATE against an existing session is invalid.
      return MeshGameRouterResult.error(MrrpStatusCode.duplicate).ackPayload;
    }
    final MeshGameCreateBody body;
    try {
      body = MeshGameCodec.decodeCreate(frame.body);
    } on FormatException {
      return MeshGameRouterResult.error(MrrpStatusCode.invalid).ackPayload;
    }
    // V1: remote-initiated CREATE is rejected — slice 1 only supports
    // locally-initiated games. Router will accept remote CREATE in
    // a later slice once channel/DM flows are designed.
    AppLogging.meshGames(
      'remote CREATE rejected type=${body.gameType.identifier} '
      'instance=${instance.instanceId}',
    );
    return MeshGameRouterResult.error(MrrpStatusCode.unsupported).ackPayload;
  }

  Future<Uint8List?> _handleJoin(
    MeshServiceInstance instance,
    int senderNodeId,
    MeshGameFrame frame,
    MeshGameSession? existing,
  ) async {
    if (existing == null) {
      return MeshGameRouterResult.error(MrrpStatusCode.notFound).ackPayload;
    }
    if (!existing.isLocalParticipant(senderNodeId)) {
      return MeshGameRouterResult.error(MrrpStatusCode.unauthorized).ackPayload;
    }
    if (existing.status.isTerminal) {
      return MeshGameRouterResult.error(MrrpStatusCode.expired).ackPayload;
    }
    final MeshGameJoinBody body;
    try {
      body = MeshGameCodec.decodeJoin(frame.body);
    } on FormatException {
      return MeshGameRouterResult.error(MrrpStatusCode.invalid).ackPayload;
    }
    if (body.revision != existing.revision) {
      return MeshGameRouterResult.error(MrrpStatusCode.invalid).ackPayload;
    }
    AppLogging.meshGames(
      'JOIN ack instance=${instance.instanceId} rev=${existing.revision}',
    );
    return MeshGameRouterResult.ok(
      MeshGameCodec.encodeJoin(
        revision: existing.revision,
        status: existing.status.code,
      ),
    ).ackPayload;
  }

  Future<Uint8List?> _handleMove(
    MeshServiceInstance instance,
    int senderNodeId,
    MeshGameFrame frame,
    MeshGameSession? existing,
  ) async {
    if (existing == null) {
      return MeshGameRouterResult.error(MrrpStatusCode.notFound).ackPayload;
    }
    if (existing.status.isTerminal) {
      return MeshGameRouterResult.error(MrrpStatusCode.expired).ackPayload;
    }
    if (!existing.isLocalParticipant(senderNodeId)) {
      return MeshGameRouterResult.error(MrrpStatusCode.unauthorized).ackPayload;
    }

    final MeshGameMoveBody body;
    try {
      body = MeshGameCodec.decodeMove(frame.body);
    } on FormatException {
      return MeshGameRouterResult.error(MrrpStatusCode.invalid).ackPayload;
    }

    // Revision gate.
    if (body.revision <= existing.revision) {
      return MeshGameRouterResult.error(MrrpStatusCode.duplicate).ackPayload;
    }
    if (body.revision != existing.revision + 1) {
      return MeshGameRouterResult.error(MrrpStatusCode.invalid).ackPayload;
    }

    final updated = _applyRemoteMove(
      session: existing,
      actorNodeNum: senderNodeId,
      moveData: body.moveData,
    );
    if (updated == null) {
      return MeshGameRouterResult.error(MrrpStatusCode.invalid).ackPayload;
    }
    await _repo.saveSession(updated);
    _onSessionChanged();
    AppLogging.meshGameSession(
      'applied remote move instance=${instance.instanceId} '
      'rev=${updated.revision} status=${updated.status.name}',
    );
    return MeshGameRouterResult.ok().ackPayload;
  }

  Future<Uint8List?> _handleStateReq(
    MeshServiceInstance instance,
    int senderNodeId,
    MeshGameSession? existing,
  ) async {
    if (existing == null) {
      return MeshGameRouterResult.error(MrrpStatusCode.notFound).ackPayload;
    }
    if (!existing.isLocalParticipant(senderNodeId)) {
      return MeshGameRouterResult.error(MrrpStatusCode.unauthorized).ackPayload;
    }
    final winnerIndex = existing.winnerNodeNum == null
        ? kMeshGameNoWinner
        : existing.participants.indexOf(existing.winnerNodeNum!);
    return MeshGameRouterResult.ok(
      MeshGameCodec.encodeStateResp(
        revision: existing.revision,
        turnIndex: existing.turnIndex & 0xFF,
        status: existing.status.code,
        winnerIndex: winnerIndex < 0 ? kMeshGameNoWinner : winnerIndex,
        stateBlob: existing.stateBlob,
      ),
    ).ackPayload;
  }

  Future<Uint8List?> _handleStateResp(
    MeshServiceInstance instance,
    int senderNodeId,
    MeshGameFrame frame,
    MeshGameSession? existing,
  ) async {
    if (existing == null) {
      return MeshGameRouterResult.error(MrrpStatusCode.notFound).ackPayload;
    }
    if (!existing.isLocalParticipant(senderNodeId)) {
      return MeshGameRouterResult.error(MrrpStatusCode.unauthorized).ackPayload;
    }
    final MeshGameStateRespBody body;
    try {
      body = MeshGameCodec.decodeStateResp(frame.body);
    } on FormatException {
      return MeshGameRouterResult.error(MrrpStatusCode.invalid).ackPayload;
    }
    if (body.revision < existing.revision) {
      return MeshGameRouterResult.error(MrrpStatusCode.duplicate).ackPayload;
    }
    final winnerNode = body.winnerIndex < existing.participants.length
        ? existing.participants[body.winnerIndex]
        : null;
    final updated = existing.copyWith(
      revision: body.revision,
      turnIndex: body.turnIndex,
      status: MeshGameStatus.fromCode(body.status) ?? MeshGameStatus.active,
      winnerNodeNum: winnerNode,
      stateBlob: body.stateBlob,
      lastMoveAt: DateTime.now(),
    );
    await _repo.saveSession(updated);
    _onSessionChanged();
    return MeshGameRouterResult.ok().ackPayload;
  }

  Future<Uint8List?> _handleQuit(
    MeshServiceInstance instance,
    int senderNodeId,
    MeshGameFrame frame,
    MeshGameSession? existing,
  ) async {
    if (existing == null) {
      return MeshGameRouterResult.error(MrrpStatusCode.notFound).ackPayload;
    }
    if (!existing.isLocalParticipant(senderNodeId)) {
      return MeshGameRouterResult.error(MrrpStatusCode.unauthorized).ackPayload;
    }
    final updated = existing.copyWith(
      status: MeshGameStatus.abandoned,
      turnIndex: -1,
      lastMoveAt: DateTime.now(),
      lastMoveBy: senderNodeId,
    );
    await _repo.saveSession(updated);
    _onSessionChanged();
    AppLogging.meshGames('QUIT accepted instance=${instance.instanceId}');
    return MeshGameRouterResult.ok().ackPayload;
  }

  /// Apply a remote move through the pure engine. Returns the updated
  /// session or null if the move was rejected.
  MeshGameSession? _applyRemoteMove({
    required MeshGameSession session,
    required int actorNodeNum,
    required Uint8List moveData,
  }) {
    final engine = GameEngineRegistry.forType(session.gameType);
    if (engine == null) return null;
    final actorIndex = session.participants.indexOf(actorNodeNum);
    if (actorIndex < 0) return null;

    try {
      final state = engine.decodeState(session.stateBlob);
      final move = engine.decodeMove(moveData);
      final result = engine.applyMove(
        state: state,
        actorIndex: actorIndex,
        move: move,
      );
      if (result is GameApplyRejected) return null;
      final accepted = result as GameApplyAccepted;
      final nextBlob = engine.encodeState(accepted.state);
      final now = DateTime.now();
      final auditMoves = [
        ...session.moves,
        MeshGameMove(
          revision: session.revision + 1,
          byNodeNum: actorNodeNum,
          data: moveData,
          acceptedAt: now,
        ),
      ];
      while (auditMoves.length > kMeshGameMoveAuditWindow) {
        auditMoves.removeAt(0);
      }
      int? winnerNode;
      if (accepted.winnerIndex != null && accepted.winnerIndex! >= 0) {
        winnerNode = session.participants[accepted.winnerIndex!];
      }
      return session.copyWith(
        revision: session.revision + 1,
        turnIndex: accepted.nextTurnIndex,
        lastMoveAt: now,
        lastMoveBy: actorNodeNum,
        status: accepted.isTerminal
            ? MeshGameStatus.completed
            : MeshGameStatus.active,
        winnerNodeNum: winnerNode,
        stateBlob: nextBlob,
        moves: auditMoves,
      );
    } catch (_) {
      return null;
    }
  }
}

typedef VoidCallback = void Function();

void _noop() {}
