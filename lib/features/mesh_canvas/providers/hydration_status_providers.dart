// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas hydration-status provider graph (S9 UI).
//
// Source of truth: docs/canvas/CANVAS_SYNC_V0_1.md §2.3 + §6.1.
//
// Exposes [meshCanvasHydrationStatusProvider] — a stream provider
// keyed by canvasLocalId that emits the current hydration state on
// every relevant change. The coordinator's broadcast `changes`
// stream drives re-emission; an initial snapshot lands synchronously
// on subscribe.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/canvas/canvas_sync_coordinator.dart';
import 'mesh_canvas_providers.dart';

final meshCanvasHydrationStatusProvider =
    StreamProvider.family<MeshCanvasHydrationState, int>((
      ref,
      canvasLocalId,
    ) async* {
      final coordinator = await ref.watch(canvasSyncCoordinatorProvider.future);
      // Seed the snapshot, then re-emit on every change event that
      // targets this canvas. The coordinator's `changes` stream is
      // broadcast, so multiple subscribers (HUD + future debug
      // overlays) share one source.
      yield coordinator.hydrationStateFor(canvasLocalId);
      await for (final id in coordinator.changes) {
        if (id != canvasLocalId) continue;
        yield coordinator.hydrationStateFor(canvasLocalId);
      }
    });

/// Raw-band reception progress for the canvas — `(received, total)`
/// for the lowest-completion in-progress band set, or `null` when no
/// raw-band sets are pending. HUD reads this alongside the
/// hydration state to render `recovering 3/8` style chrome.
/// Spec: CANVAS_SYNC_V0_1.md §11.5.
final meshCanvasBandProgressProvider =
    StreamProvider.family<({int received, int total})?, int>((
      ref,
      canvasLocalId,
    ) async* {
      final coordinator = await ref.watch(canvasSyncCoordinatorProvider.future);
      yield coordinator.bandProgressForCanvas(canvasLocalId);
      await for (final id in coordinator.changes) {
        if (id != canvasLocalId) continue;
        yield coordinator.bandProgressForCanvas(canvasLocalId);
      }
    });
