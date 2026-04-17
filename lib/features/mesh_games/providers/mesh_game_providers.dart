// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Riverpod wiring for the mesh-games feature.
///
/// Exposes:
///   * [meshGameRateLimiterProvider]
///   * [meshGameRepositoryProvider]
///   * [meshGameRouterProvider] — also installs itself on
///     [MeshServiceEngine.gameInteractionHandler] so inbound MRRP
///     `interact` payloads with `canonicalType == game` are routed
///     into this feature.
///   * [meshGameTransportProvider]
///   * [meshGamesEpochProvider] — bumped whenever session state
///     changes, so UI providers can invalidate deterministically.
///   * [meshGameSessionProvider] — per-session state.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../mesh_services/providers/mesh_service_providers.dart';
import '../../mesh_services/services/mesh_service_engine.dart';
import '../data/mesh_game_rate_limiter.dart';
import '../data/mesh_game_repository.dart';
import '../engine/game_engine.dart';
import '../engine/game_engine_registry.dart';
import '../models/mesh_game_move.dart';
import '../models/mesh_game_session.dart';
import '../models/mesh_game_status.dart';
import '../transport/mesh_game_router.dart';
import '../transport/mesh_game_transport.dart';

/// Epoch counter bumped whenever a game session changes on disk.
final meshGamesEpochProvider = NotifierProvider<_MeshGamesEpoch, int>(
  _MeshGamesEpoch.new,
);

class _MeshGamesEpoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Shared inbound rate limiter.
final meshGameRateLimiterProvider = Provider<MeshGameRateLimiter>((ref) {
  return MeshGameRateLimiter();
});

/// Durable session repository.
///
/// Null when the mesh-services store is unavailable (feature flag off,
/// database failed to open, etc.).
final meshGameRepositoryProvider = Provider<MeshGameRepository?>((ref) {
  final store = ref.watch(meshServiceStoreProvider);
  if (store == null) return null;
  return MeshGameRepository(store: store);
});

/// Inbound mesh-game router; wires itself onto the mesh-service
/// engine's `gameInteractionHandler` slot.
///
/// This is the integration point: creating this provider causes the
/// existing [MeshServicesHandler] to start delegating
/// `canonicalType == game` interactions into the router without any
/// further coupling inside the engine.
final meshGameRouterProvider = Provider<MeshGameRouter?>((ref) {
  final engine = ref.watch(meshServiceEngineProvider);
  final repository = ref.watch(meshGameRepositoryProvider);
  if (engine == null || repository == null) return null;

  final router = MeshGameRouter(
    repository: repository,
    rateLimiter: ref.watch(meshGameRateLimiterProvider),
    onSessionChanged: () {
      ref.read(meshGamesEpochProvider.notifier).bump();
    },
  );
  engine.gameInteractionHandler = router.handle;
  ref.onDispose(() {
    if (engine.gameInteractionHandler == router.handle) {
      engine.gameInteractionHandler = null;
    }
  });
  AppLogging.meshGames('router attached to mesh_service_engine');
  return router;
});

/// Outbound mesh-game transport. Null when MRRP isn't running.
final meshGameTransportProvider = Provider<MeshGameTransport?>((ref) {
  final tracker = ref.watch(mrrpDeliveryTrackerProvider);
  if (tracker == null) return null;
  return MeshGameTransport(tracker: tracker);
});

/// Snapshot of a single session keyed by its instance ID.
///
/// Rebuilds when [meshGamesEpochProvider] is bumped by inbound moves,
/// or when an explicit `ref.invalidate` is issued locally.
final meshGameSessionProvider = FutureProvider.family<MeshGameSession?, String>(
  (ref, instanceId) async {
    ref.watch(meshGamesEpochProvider);
    final repo = ref.watch(meshGameRepositoryProvider);
    if (repo == null) return null;
    await repo.open();
    return repo.loadSession(instanceId);
  },
);

/// All active local game sessions. Used by my-services list to render
/// the Games filter.
final meshGameActiveSessionsProvider = FutureProvider<List<MeshGameSession>>((
  ref,
) async {
  ref.watch(meshGamesEpochProvider);
  final repo = ref.watch(meshGameRepositoryProvider);
  if (repo == null) return const [];
  await repo.open();
  return repo.listActiveGames();
});

/// Result of a local-move attempt, returned to UI.
enum MeshGameLocalMoveOutcome {
  /// Move applied locally; send attempted.
  accepted,

  /// Engine rejected the move (invalid cell, not your turn, etc.).
  rejectedByEngine,

  /// Transport failed — session advanced locally; UI should show
  /// resync affordance.
  transportFailed,

  /// Session/Engine/transport/repo missing.
  notReady,
}

class MeshGameLocalMoveResult {
  final MeshGameLocalMoveOutcome outcome;
  final MeshGameSession? session;

  const MeshGameLocalMoveResult({required this.outcome, this.session});
}

/// Apply a local move optimistically: validate, persist, send.
///
/// The session advance is durable *before* the send — per spec § 6.2
/// we rely on revision gating to make the move re-sendable rather
/// than relying on automatic retry.
///
/// Called from widget code; [ref] is a [WidgetRef].
Future<MeshGameLocalMoveResult> applyLocalMeshGameMove({
  required WidgetRef ref,
  required String instanceId,
  required int myNodeNum,
  required Object move,
}) async {
  final repo = ref.read(meshGameRepositoryProvider);
  final transport = ref.read(meshGameTransportProvider);
  if (repo == null || transport == null) {
    return const MeshGameLocalMoveResult(
      outcome: MeshGameLocalMoveOutcome.notReady,
    );
  }
  await repo.open();
  final session = await repo.loadSession(instanceId);
  if (session == null || session.status.isTerminal) {
    return const MeshGameLocalMoveResult(
      outcome: MeshGameLocalMoveOutcome.notReady,
    );
  }
  final engine = GameEngineRegistry.forType(session.gameType);
  if (engine == null) {
    return const MeshGameLocalMoveResult(
      outcome: MeshGameLocalMoveOutcome.notReady,
    );
  }
  final actorIndex = session.participants.indexOf(myNodeNum);
  if (actorIndex < 0) {
    return const MeshGameLocalMoveResult(
      outcome: MeshGameLocalMoveOutcome.rejectedByEngine,
    );
  }

  final state = engine.decodeState(session.stateBlob);
  final result = engine.applyMove(
    state: state,
    actorIndex: actorIndex,
    move: move,
  );
  if (result is GameApplyRejected) {
    AppLogging.meshGames(
      'local move rejected reason=${result.reason} instance=$instanceId',
    );
    return const MeshGameLocalMoveResult(
      outcome: MeshGameLocalMoveOutcome.rejectedByEngine,
    );
  }
  final accepted = result as GameApplyAccepted;
  final newBlob = engine.encodeState(accepted.state);
  final moveBytes = engine.encodeMove(move);
  final now = DateTime.now();
  final auditMoves = [
    ...session.moves,
    MeshGameMove(
      revision: session.revision + 1,
      byNodeNum: myNodeNum,
      data: moveBytes,
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
  final updated = session.copyWith(
    revision: session.revision + 1,
    turnIndex: accepted.nextTurnIndex,
    lastMoveAt: now,
    lastMoveBy: myNodeNum,
    status: accepted.isTerminal
        ? MeshGameStatus.completed
        : MeshGameStatus.active,
    winnerNodeNum: winnerNode,
    stateBlob: newBlob,
    moves: auditMoves,
  );
  await repo.saveSession(updated);
  ref.read(meshGamesEpochProvider.notifier).bump();

  final send = await transport.sendMove(
    session: updated,
    revision: updated.revision,
    moveData: Uint8List.fromList(moveBytes),
  );
  return MeshGameLocalMoveResult(
    outcome: send.ok
        ? MeshGameLocalMoveOutcome.accepted
        : MeshGameLocalMoveOutcome.transportFailed,
    session: updated,
  );
}
