// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../providers/app_providers.dart';
import '../../../services/notifications/notification_service.dart';
import '../../../services/protocol/protocol_service.dart';
import '../models/mesh_waypoint.dart';
import '../services/waypoint_database.dart';
import '../../../providers/radio_scope_providers.dart';

/// SQLite store for received/created Meshtastic waypoints (singleton).
final waypointDatabaseProvider = Provider<WaypointDatabase>((ref) {
  ref.watch(radioScopeProvider);
  final db = WaypointDatabase();
  bindStoreToRadioScope(ref, db, db.close);
  return db;
});

/// Owns the live waypoint list, backed by SQLite.
///
/// On build it loads persisted (non-expired) waypoints, subscribes to the
/// protocol [ProtocolService.waypointStream], applies the official Meshtastic
/// reconciliation rules, and runs periodic expiry cleanup. The reconciliation
/// rules mirror the firmware/iOS behaviour:
///
/// - `isDelete` (wire `expire == 1`): remove locally.
/// - real expiry already passed: treat as a delete.
/// - unknown id: insert.
/// - known id: update only when the existing waypoint is unlocked, or the
///   update comes from the locking node.
final waypointsNotifierProvider =
    AsyncNotifierProvider<WaypointsNotifier, List<MeshWaypoint>>(
      WaypointsNotifier.new,
    );

class WaypointsNotifier extends AsyncNotifier<List<MeshWaypoint>> {
  StreamSubscription<MeshWaypointEvent>? _sub;
  Timer? _cleanupTimer;
  int? _myNodeNum;

  @override
  Future<List<MeshWaypoint>> build() async {
    final db = ref.read(waypointDatabaseProvider);
    await db.init();

    _myNodeNum = ref.read(myNodeNumProvider);

    final persisted = await db.getAll();
    AppLogging.map(
      'WaypointsNotifier: loaded ${persisted.length} waypoints from database',
    );

    final protocol = ref.read(protocolServiceProvider);
    _sub = protocol.waypointStream.listen(_onEvent);

    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _runCleanup(),
    );

    ref.onDispose(() {
      _sub?.cancel();
      _cleanupTimer?.cancel();
    });

    return persisted;
  }

  Future<void> _onEvent(MeshWaypointEvent event) async {
    final db = ref.read(waypointDatabaseProvider);
    final current = List<MeshWaypoint>.of(state.value ?? const []);

    // Delete sentinel or already-expired waypoint → remove locally.
    if (event.isDelete ||
        (event.expire > 1 &&
            event.expire * 1000 <= DateTime.now().millisecondsSinceEpoch)) {
      await db.deleteById(event.id);
      current.removeWhere((w) => w.id == event.id);
      state = AsyncData(current);
      return;
    }

    final incoming = MeshWaypoint.fromEvent(event, myNodeNum: _myNodeNum);
    final idx = current.indexWhere((w) => w.id == incoming.id);

    if (idx >= 0) {
      // Locked-edit rule: reject updates to a locked waypoint unless the
      // update originates from the node that owns the lock.
      final existing = current[idx];
      if (existing.isLocked && event.fromNodeNum != existing.lockedTo) {
        AppLogging.map(
          'WaypointsNotifier: rejected update to locked waypoint '
          'id=${existing.id} from=${event.fromNodeNum.toRadixString(16)}',
        );
        return;
      }
      await db.upsert(incoming);
      current[idx] = incoming;
    } else {
      await db.upsert(incoming);
      current.insert(0, incoming);
    }
    state = AsyncData(current);

    // Notify on inbound waypoints from other nodes (never our own echo).
    if (!incoming.isMine) {
      final nodes = ref.read(nodesProvider);
      final senderName =
          nodes[event.fromNodeNum]?.displayName ??
          '!${event.fromNodeNum.toRadixString(16)}';
      unawaited(
        NotificationService().showWaypointNotification(
          waypointId: incoming.id,
          name: incoming.name,
          senderName: senderName,
        ),
      );
    }
  }

  Future<void> _runCleanup() async {
    final db = ref.read(waypointDatabaseProvider);
    final removed = await db.cleanupExpired();
    if (removed > 0) {
      final current = List<MeshWaypoint>.of(state.value ?? const [])
        ..removeWhere((w) => w.isExpired);
      state = AsyncData(current);
    }
  }

  /// Create a new waypoint or broadcast an edit to an existing one.
  Future<void> createOrUpdate(MeshWaypoint waypoint) async {
    final protocol = ref.read(protocolServiceProvider);
    await protocol.sendWaypoint(
      id: waypoint.id,
      latitude: waypoint.latitude,
      longitude: waypoint.longitude,
      name: waypoint.name,
      description: waypoint.description,
      icon: waypoint.icon,
      expire: waypoint.expire,
      lockedTo: waypoint.lockedTo,
    );
    // sendWaypoint self-echoes onto the stream; _onEvent persists + updates
    // state, so no direct mutation is needed here.
  }

  /// Broadcast a "delete for everyone" (expire = 1) and remove locally.
  Future<void> deleteForEveryone(MeshWaypoint waypoint) async {
    final protocol = ref.read(protocolServiceProvider);
    await protocol.sendWaypoint(
      id: waypoint.id,
      latitude: waypoint.latitude,
      longitude: waypoint.longitude,
      expire: 1,
    );
  }

  /// Remove a waypoint from local storage only (no broadcast).
  Future<void> deleteForMe(int id) async {
    final db = ref.read(waypointDatabaseProvider);
    await db.deleteById(id);
    final current = List<MeshWaypoint>.of(state.value ?? const [])
      ..removeWhere((w) => w.id == id);
    state = AsyncData(current);
  }
}

/// Flat list of current waypoints for the map and lists.
final meshWaypointsProvider = Provider<List<MeshWaypoint>>((ref) {
  return ref.watch(waypointsNotifierProvider).value ?? const [];
});
