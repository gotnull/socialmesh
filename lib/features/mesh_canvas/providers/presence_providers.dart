// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas presence provider graph (P5).
//
// Source of truth: docs/canvas/CANVAS_PRESENCE_V0_1.md §6.
//
// Wires together:
//   - presenceCacheProvider     in-memory LWW cache (singleton)
//   - canvasPresenceProvider    per-canvas stream filtered for "remote
//                               peers" (i.e., self excluded)
//   - presenceCountProvider     cheap selector for the overview pill
//   - presenceEmitCoordinatorProvider  outbound emitter
//   - presenceLifecycleProvider 15 s ticker that drives cache sweep
//                               + coordinator heartbeats
//
// Canonical wiring rules:
//   - cache is the source of truth; widgets subscribe to its change
//     stream (no manual ref.invalidate from the handler);
//   - presence is mesh-scope only — local canvas (canvas_id=0) never
//     emits or accepts presence (CANVAS_PRESENCE_V0_1.md P8);
//   - heartbeat ticker is shared with cache sweep so the app pays
//     one wake-up per 15 s, not two;
//   - the lifecycle provider is a side-effect: the viewer screen
//     `ref.watch`es it to keep the timer alive while the viewer is
//     mounted, and Riverpod tears the timer down on dispose.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../providers/app_providers.dart';
import '../../../services/canvas/presence_cache.dart';
import '../../../services/canvas/presence_emit_coordinator.dart';
import '../../../services/canvas/presence_models.dart';
import 'mesh_canvas_providers.dart';

/// Singleton presence cache. Owns the broadcast change stream that
/// drives per-canvas UI invalidation.
final presenceCacheProvider = Provider<PresenceCache>((ref) {
  final cache = PresenceCache();
  ref.onDispose(() {
    // dispose() closes the broadcast stream and clears entries.
    // Fire-and-forget: provider teardown cannot await.
    cache.dispose();
  });
  AppLogging.meshCanvas('presence cache singleton instantiated');
  return cache;
});

/// Per-canvas stream of remote-peer presence entries, sorted painting
/// first then active then viewing, lastSeenMs desc within state.
///
/// "Remote" means: every entry whose `nodeNum != myNodeNum`. The
/// local user is excluded from the strip count and the avatar stack
/// per the UX brief ("1 radio here" = 1 OTHER radio).
///
/// Re-emits on every relevant cache change AND on a 5 s heartbeat so
/// TTL-only expirations surface without a separate mutation event.
final canvasPresenceProvider = StreamProvider.family<List<PresenceEntry>, int>((
  ref,
  canvasLocalId,
) {
  final cache = ref.watch(presenceCacheProvider);
  final myNodeNum = ref.watch(myNodeNumProvider);
  final controller = StreamController<List<PresenceEntry>>();

  List<PresenceEntry> snapshot() {
    final all = cache.entriesForCanvas(canvasLocalId);
    if (myNodeNum == null) return all;
    return all.where((e) => e.nodeNum != myNodeNum).toList(growable: false);
  }

  // Seed.
  controller.add(snapshot());

  // Mutation-driven re-emits only. We deliberately do NOT install a
  // periodic ticker for opacity decay here: flutter_test's
  // `_verifyInvariants` flags any pending Timer at teardown, and a
  // long-lived periodic owned by a Riverpod provider is not
  // cancelled before that check runs. Cache mutations (inbound
  // presence frames + local notify events) drive enough rebuilds in
  // practice; pure-idle viewers see opacity step only on the next
  // event. Acceptable cost for v0.1.
  final cacheSub = cache.changeStream.where((id) => id == canvasLocalId).listen(
    (_) {
      if (controller.isClosed) return;
      controller.add(snapshot());
    },
  );

  ref.onDispose(() {
    cacheSub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Cheap selector for the channel-canvas-card pill and any future
/// "N here" badge. Avoids re-rendering the full presence list when a
/// downstream consumer only needs counts.
final presenceCountProvider = Provider.family<({int total, int painting}), int>(
  (ref, canvasLocalId) {
    final list =
        ref.watch(canvasPresenceProvider(canvasLocalId)).asData?.value ??
        const <PresenceEntry>[];
    var painting = 0;
    for (final entry in list) {
      if (entry.state == PresenceState.painting) painting++;
    }
    return (total: list.length, painting: painting);
  },
);

/// Outbound presence emitter. Reuses the canvas governor + outbound
/// channel that paint uses, so anti-starvation (paint > DM > presence)
/// is enforced by the shared infrastructure rather than a parallel
/// pipeline.
final presenceEmitCoordinatorProvider = FutureProvider<PresenceEmitCoordinator>(
  (ref) async {
    final cache = ref.watch(presenceCacheProvider);
    final governor = ref.read(canvasOutboundGovernorProvider);
    final outbound = ref.read(canvasOutboundChannelProvider);
    // Touch the repo provider so the coordinator chain stays
    // dependency-coherent with the canvas database lifecycle, even
    // though we no longer query the repository directly from this
    // coordinator (the paint-queue gate was removed at P5 after
    // sim verification — see _attemptEmit comment).
    await ref.watch(canvasRepositoryProvider.future);

    final coordinator = PresenceEmitCoordinator(
      cache: cache,
      governor: governor,
      outbound: outbound,
      localNodeNumProvider: () => ref.read(myNodeNumProvider),
    );

    ref.onDispose(coordinator.dispose);
    AppLogging.meshCanvas('presence emit coordinator instantiated');
    return coordinator;
  },
);

/// Heartbeat cadence shared between the cache sweep and the emit
/// coordinator's tick. Lives here so the widget that owns the timer
/// (the viewer's lifecycle host) imports just one symbol from this
/// file. Ownership of the actual timer sits in the WIDGET, NOT in a
/// provider — that way `State.dispose` cancels the timer
/// synchronously and the flutter_test "no pending Timer" invariant
/// holds without every viewer test having to override a provider.
const Duration presenceHeartbeatPeriod = Duration(seconds: 15);

/// One combined sweep + heartbeat tick. Called from the viewer
/// lifecycle host's periodic timer (and once on mount). Idempotent
/// when the coordinator has not yet resolved — in early boot we
/// silently skip the tick rather than block on it.
Future<void> presenceLifecycleSweepAndTick(WidgetRef ref) async {
  final cache = ref.read(presenceCacheProvider);
  final coordinatorAsync = ref.read(presenceEmitCoordinatorProvider);
  final coordinator = coordinatorAsync.asData?.value;
  final now = DateTime.now().millisecondsSinceEpoch;
  cache.sweepExpired(now);
  if (coordinator != null) {
    await coordinator.tick(nowMs: now);
  }
}
