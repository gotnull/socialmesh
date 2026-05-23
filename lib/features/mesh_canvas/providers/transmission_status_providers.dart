// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas transmission-status provider graph.
//
// Source of truth: docs/canvas/CANVAS_TRANSMISSION_STATUS_V0_1.md §4.
//
// Surfaces airtime + queue state from the canvas governor, send
// coordinator, and `pending_op` table so the UI tier can render the
// transmission HUD pill and apply the pending-pixel visual treatment.
//
// Both providers emit a fresh snapshot every 2 seconds while
// subscribed; this is the cheapest pattern that lets `cooling` decay
// to `idle` even when no paint activity is happening. The repository
// query is bounded to one `SELECT` per canvas per tick.
//
// Mesh-scope only. The HUD widget gates by scope upstream; here we
// return idle-shaped data for any canvas whose pending count is 0 so
// consumers do not need to branch on scope.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/canvas/canvas_constants.dart';
import '../../../services/canvas/canvas_outbound_governor.dart';
import '../../../services/canvas/canvas_repository.dart';
import '../../../services/canvas/canvas_send_coordinator.dart';
import '../../../services/canvas/canvas_transmission_status_models.dart';
import 'mesh_canvas_providers.dart';

/// Cadence at which the view model re-polls the repository + governor
/// + coordinator. Two seconds is the sweet spot: fast enough that
/// `cooling` clears within ~7 seconds of the SIP backoff resolving;
/// slow enough that the additional DB pressure is invisible (one
/// `SELECT COUNT(*)` per active viewer per tick).
const Duration _kStatusTickPeriod = Duration(seconds: 2);

/// Per-canvas transmission status. Emits:
///   - an initial snapshot immediately on subscribe;
///   - a fresh snapshot every [_kStatusTickPeriod] thereafter;
///   - `MeshCanvasTransmissionStatus.idle` when any required upstream
///     dependency is still loading.
///
/// Uses an `async*` generator so the framework auto-cancels the
/// underlying stream subscription on dispose — no manual
/// StreamController + onDispose dance required.
final meshCanvasTransmissionStatusProvider =
    StreamProvider.family<MeshCanvasTransmissionStatus, int>((
      ref,
      canvasLocalId,
    ) async* {
      final repo = await ref.watch(canvasRepositoryProvider.future);
      final coordinator = await ref.watch(canvasSendCoordinatorProvider.future);
      final governor = ref.read(canvasOutboundGovernorProvider);

      yield await computeTransmissionStatus(
        repo: repo,
        coordinator: coordinator,
        governor: governor,
        canvasLocalId: canvasLocalId,
      );
      await for (final _ in Stream<void>.periodic(_kStatusTickPeriod)) {
        yield await computeTransmissionStatus(
          repo: repo,
          coordinator: coordinator,
          governor: governor,
          canvasLocalId: canvasLocalId,
        );
      }
    });

/// Compute one transmission-status snapshot from the live inputs.
///
/// Public so widget tests and integration tests can verify status
/// derivation without spinning up the StreamProvider's periodic
/// emission loop.
Future<MeshCanvasTransmissionStatus> computeTransmissionStatus({
  required CanvasRepository repo,
  required CanvasSendCoordinator coordinator,
  required CanvasOutboundGovernor governor,
  required int canvasLocalId,
  int? nowMsOverride,
}) async {
  final stats = await repo.pendingStatsForCanvas(canvasLocalId);
  final nowMs = nowMsOverride ?? DateTime.now().millisecondsSinceEpoch;
  return MeshCanvasTransmissionStatus.derive(
    pendingCount: stats.count,
    oldestPendingAtMs: stats.oldestCreatedAtMs,
    nextAttemptAtMs: stats.nextAttemptAtMs,
    governorRemainingBytes: governor.remainingBytes,
    lastSipDenialAtMs: coordinator.lastSipDenialAtMs,
    nowMs: nowMs,
  );
}

/// Per-canvas set of pending cell coordinates, packed as
/// `y * widthCells + x`. The painter blends these cells at reduced
/// opacity so users see at a glance which paints are still in flight.
///
/// Emits on the same 2-second tick as the status provider so the two
/// stay in lockstep without doubling the DB pressure.
final meshCanvasPendingCellsProvider = StreamProvider.family<Set<int>, int>((
  ref,
  canvasLocalId,
) async* {
  final repo = await ref.watch(canvasRepositoryProvider.future);
  yield await repo.getPendingCellCoordinates(
    canvasLocalId,
    widthCells: CanvasGeometry.width,
  );
  await for (final _ in Stream<void>.periodic(_kStatusTickPeriod)) {
    yield await repo.getPendingCellCoordinates(
      canvasLocalId,
      widthCells: CanvasGeometry.width,
    );
  }
});
