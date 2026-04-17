// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Durable store facade for mesh game sessions.
///
/// Wraps [MeshServiceStore] so game sessions are persisted inside the
/// existing `service_instances` table with `canonical_type = 'game'`.
/// No new SQLite database; no new schema migration required. See
/// `docs/mesh_games/MESH_GAMES_V0_1.md` § 4.
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import '../../mesh_services/models/mesh_service_instance.dart';
import '../../mesh_services/models/mesh_service_template.dart';
import '../../mesh_services/services/mesh_service_store.dart';
import '../models/mesh_game_session.dart';
import '../models/mesh_game_status.dart';
import '../models/mesh_game_type.dart';

/// Default TTL for a new game session. Auto-abandons after inactivity.
const Duration kMeshGameSessionTtl = Duration(days: 7);

/// Thin repository atop [MeshServiceStore] for mesh-game sessions.
class MeshGameRepository {
  final MeshServiceStore _store;
  final DateTime Function() _clock;

  MeshGameRepository({
    required MeshServiceStore store,
    DateTime Function()? clock,
  }) : _store = store,
       _clock = clock ?? DateTime.now;

  Future<void> open() => _store.open();

  /// Create a new local game session backed by a fresh
  /// [MeshServiceInstance] row. Returns the instance wrapper and the
  /// session on success; returns null if the underlying store insert
  /// fails.
  Future<({MeshServiceInstance instance, MeshGameSession session})?>
  createLocalSession({
    required String instanceId,
    required MeshGameType gameType,
    MeshServicePresetId? presetId,
    required String title,
    String description = '',
    required List<int> participants,
    required int initiatorNodeNum,
    required int turnIndex,
    required Uint8List initialStateBlob,
  }) async {
    final now = _clock();
    final session = MeshGameSession(
      instanceId: instanceId,
      gameType: gameType,
      participants: List<int>.unmodifiable(participants),
      initiatorNodeNum: initiatorNodeNum,
      turnIndex: turnIndex,
      revision: 0,
      lastMoveAt: now,
      lastMoveBy: initiatorNodeNum,
      status: MeshGameStatus.active,
      stateBlob: initialStateBlob,
    );
    final instance = MeshServiceInstance(
      instanceId: instanceId,
      canonicalType: MeshServiceType.game,
      presetId: presetId,
      title: title,
      description: description,
      createdAt: now,
      expiresAt: now.add(kMeshGameSessionTtl),
      status: MeshServiceStatus.active,
      config: session.toConfig(),
    );
    final ok = await _store.insert(instance);
    if (!ok) return null;
    AppLogging.meshGameSession(
      'created session=$instanceId type=${gameType.identifier}',
    );
    return (instance: instance, session: session);
  }

  /// Load a session if one exists with the given ID.
  Future<MeshGameSession?> loadSession(String instanceId) async {
    final instance = await _store.get(instanceId);
    if (instance == null) return null;
    if (instance.canonicalType != MeshServiceType.game) return null;
    return MeshGameSession.tryFromConfig(
      instanceId: instanceId,
      config: instance.config,
    );
  }

  /// Load the raw [MeshServiceInstance] backing a game session.
  Future<MeshServiceInstance?> loadInstance(String instanceId) =>
      _store.get(instanceId);

  /// Persist updated session state.
  Future<void> saveSession(MeshGameSession session) async {
    final instance = await _store.get(session.instanceId);
    if (instance == null) {
      AppLogging.meshGameSession(
        'save ignored — instance missing ${session.instanceId}',
      );
      return;
    }
    final updated = instance.copyWith(
      config: session.toConfig(),
      status: session.status.isTerminal
          ? MeshServiceStatus.stopped
          : instance.status,
    );
    await _store.update(updated);
    AppLogging.meshGameSession(
      'persisted session=${session.instanceId} rev=${session.revision} '
      'status=${session.status.name}',
    );
  }

  /// List all active local game sessions.
  Future<List<MeshGameSession>> listActiveGames() async {
    final active = await _store.getActive();
    return active
        .where((inst) => inst.canonicalType == MeshServiceType.game)
        .map(
          (inst) => MeshGameSession.tryFromConfig(
            instanceId: inst.instanceId,
            config: inst.config,
          ),
        )
        .whereType<MeshGameSession>()
        .toList(growable: false);
  }

  /// Delete a session row permanently.
  Future<void> deleteSession(String instanceId) async {
    await _store.delete(instanceId);
    AppLogging.meshGameSession('deleted session=$instanceId');
  }
}
