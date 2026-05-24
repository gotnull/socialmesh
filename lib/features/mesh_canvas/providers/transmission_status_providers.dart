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
// Event-driven: re-emits when the repository's `pendingChangeStream`
// fires for this canvas, when cadence cooling flips, or on a slow
// 15-second fallback heartbeat that lets SIP-denial cooling decay to
// idle without paint activity. Switching from the prior 2-second
// poll cut idle-viewer DB pressure by ~7x and removed a per-second
// wakeup that showed up in battery profiling.
//
// Mesh-scope only. The HUD widget gates by scope upstream; here we
// return idle-shaped data for any canvas whose pending count is 0 so
// consumers do not need to branch on scope.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/canvas/canvas_constants.dart';
import '../../../services/canvas/canvas_outbound_governor.dart';
import '../../../services/canvas/canvas_paint_cadence.dart';
import '../../../services/canvas/canvas_repository.dart';
import '../../../services/canvas/canvas_send_coordinator.dart';
import '../../../services/canvas/canvas_transmission_status_models.dart';
import 'mesh_canvas_providers.dart';

/// Singleton cadence gate. Per-canvas in-memory tap timestamps; held
/// alive for the app's lifetime so a viewer rebuild doesn't reset the
/// cooldown the user just landed.
final meshCanvasPaintCadenceProvider = Provider<CanvasPaintCadence>((ref) {
  final cadence = CanvasPaintCadence();
  ref.onDispose(cadence.dispose);
  return cadence;
});

/// Fallback heartbeat. The cadence singleton intentionally does NOT
/// schedule its own cooldown-expiry Timer (it would trip
/// flutter_test's "Timer still pending" invariant — see
/// [CanvasPaintCadence.recordTap]), so this heartbeat is the path
/// that lets `cooling` decay to `idle` when no other event fires.
/// 5 s is 2x the cadence cooldown window (2.5 s), so the HUD stays
/// in `cooling` for at most one heartbeat past the real cooldown
/// release. Idle viewers do ~12 wakes/min instead of the prior 30,
/// while still surfacing SIP-denial cooling decay promptly.
const Duration _kStatusFallbackPeriod = Duration(seconds: 5);

/// Per-canvas transmission status. Emits:
///   - an initial snapshot immediately on subscribe;
///   - a fresh snapshot on every `pendingChangeStream` event for this
///     canvas (insert / delete / state transition);
///   - a fresh snapshot when cadence cooling flips for this canvas;
///   - a fallback snapshot every [_kStatusFallbackPeriod] so SIP
///     cooling decay surfaces with no paint activity;
///   - `MeshCanvasTransmissionStatus.idle` when any required upstream
///     dependency is still loading.
final meshCanvasTransmissionStatusProvider =
    StreamProvider.family<MeshCanvasTransmissionStatus, int>((
      ref,
      canvasLocalId,
    ) async* {
      final repo = await ref.watch(canvasRepositoryProvider.future);
      final coordinator = await ref.watch(canvasSendCoordinatorProvider.future);
      final governor = ref.read(canvasOutboundGovernorProvider);
      final cadence = ref.read(meshCanvasPaintCadenceProvider);

      yield await computeTransmissionStatus(
        repo: repo,
        coordinator: coordinator,
        governor: governor,
        cadence: cadence,
        canvasLocalId: canvasLocalId,
      );

      final trigger = StreamController<void>();
      void wake(int _) {
        if (!trigger.isClosed) trigger.add(null);
      }

      final repoSub = repo.pendingChangeStream
          .where((id) => id == canvasLocalId)
          .listen(wake);
      final cadenceSub = cadence.changes
          .where((id) => id == canvasLocalId)
          .listen(wake);
      final fallbackSub = Stream<void>.periodic(_kStatusFallbackPeriod).listen((
        _,
      ) {
        if (!trigger.isClosed) trigger.add(null);
      });
      ref.onDispose(() {
        repoSub.cancel();
        cadenceSub.cancel();
        fallbackSub.cancel();
        trigger.close();
      });

      await for (final _ in trigger.stream) {
        yield await computeTransmissionStatus(
          repo: repo,
          coordinator: coordinator,
          governor: governor,
          cadence: cadence,
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
  CanvasPaintCadence? cadence,
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
    isCadenceCooling: cadence?.isCoolingDown(canvasLocalId) ?? false,
  );
}

/// Per-canvas set of pending cell coordinates, packed as
/// `y * widthCells + x`. The painter blends these cells at reduced
/// opacity so users see at a glance which paints are still in flight.
///
/// Purely event-driven: pending cells only change when a `pending_op`
/// row is inserted, updated, or deleted, all of which fire the
/// repository's `pendingChangeStream`. No periodic poll.
final meshCanvasPendingCellsProvider = StreamProvider.family<Set<int>, int>((
  ref,
  canvasLocalId,
) async* {
  final repo = await ref.watch(canvasRepositoryProvider.future);
  yield await repo.getPendingCellCoordinates(
    canvasLocalId,
    widthCells: CanvasGeometry.width,
  );
  await for (final _ in repo.pendingChangeStream.where(
    (id) => id == canvasLocalId,
  )) {
    yield await repo.getPendingCellCoordinates(
      canvasLocalId,
      widthCells: CanvasGeometry.width,
    );
  }
});
