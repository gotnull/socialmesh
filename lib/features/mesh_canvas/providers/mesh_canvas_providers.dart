// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Riverpod scaffolding for the MeshCanvas feature.
//
// Spec anchor: docs/canvas/CANVAS_V0_1.md §S0 product invariants.
// S8 wired the production protocol stack — paint ops on a Mesh
// Canvas now enqueue, drain through the canvas governor + SIP
// limiter, and ride out as canvas.v1 MRRP frames. Digest / sync
// catch-up lands in S9.
//
// Riverpod conventions in this codebase (lib/providers/CLAUDE.md):
//   - Riverpod 3.x only; no StateNotifier / StateProvider /
//     ChangeNotifierProvider.
//   - No business logic inside Notifier.build(); delegate to the
//     repository or codec.
//   - `ref.onDispose` on every provider that creates an owning
//     resource (CanvasDatabase here).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/canvas/canvas_palette.dart';
import '../../../core/logging.dart';
import '../../../models/mesh_models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/sip_providers.dart';
import '../../../services/canvas/canvas_constants.dart';
import '../../../services/canvas/canvas_database.dart';
import '../../../services/canvas/canvas_models.dart';
import '../../../services/canvas/canvas_outbound_channel_impl.dart';
import '../../../services/canvas/canvas_outbound_governor.dart';
import '../../../services/canvas/canvas_repository.dart';
import '../../../services/canvas/canvas_send_coordinator.dart';
import '../../../services/canvas/canvas_sync_coordinator.dart';
import '../../../services/canvas/mrrp_service_canvas.dart';
import 'mesh_canvas_participation_providers.dart';
import 'presence_providers.dart';

/// Owns the `canvas.db` connection for the app's lifetime.
final canvasDatabaseProvider = FutureProvider<CanvasDatabase>((ref) async {
  final db = CanvasDatabase();
  await db.init();
  ref.onDispose(() {
    // Close is fire-and-forget; provider teardown can't await.
    db.close();
  });
  return db;
});

/// Typed CRUD layer over [canvasDatabaseProvider].
final canvasRepositoryProvider = FutureProvider<CanvasRepository>((ref) async {
  final db = await ref.watch(canvasDatabaseProvider.future);
  final repo = CanvasRepository(db);
  ref.onDispose(repo.dispose);
  return repo;
});

/// The auto-created Local Device Canvas (`scope = 'local'`). Always
/// returns a row — created on first read, returned thereafter.
final localDeviceCanvasProvider = FutureProvider<CanvasSummary>((ref) async {
  final repo = await ref.watch(canvasRepositoryProvider.future);
  return repo.getOrCreateLocalCanvas();
});

/// All canvases known to this device, newest-activity first. Drives
/// the S7.C overview list. The Local Device Canvas is auto-created
/// on first read so the local section always has something to show
/// — fresh installs would otherwise land on an awkward empty state
/// for the only canvas every user definitely owns.
final canvasListProvider = FutureProvider<List<CanvasSummary>>((ref) async {
  // Ensure the local sandbox exists before we list.
  await ref.watch(localDeviceCanvasProvider.future);
  final repo = await ref.watch(canvasRepositoryProvider.future);
  return repo.listCanvases();
});

/// Painted cells for a specific canvas. The S7.A viewer reads this for
/// the Local Device Canvas. Re-fetched whenever `ref.invalidate` is
/// called on the family entry (the painter callback does this after
/// every accepted paint).
final canvasCellsProvider = FutureProvider.family<List<CanvasCell>, int>((
  ref,
  canvasLocalId,
) async {
  final repo = await ref.watch(canvasRepositoryProvider.future);
  return repo.getCanvasCells(canvasLocalId);
});

/// User's currently-selected palette index. Defaults to palette index
/// 8 (black) — a sensible "any colour but the erase sentinel" start.
/// In S7.A, only [SocialMeshPalette.quickStripIndices] values flow
/// through here from the bottom strip; the full sheet in S7.B can
/// emit any index in 0..63.
final selectedColorProvider = NotifierProvider<SelectedColorNotifier, int>(
  SelectedColorNotifier.new,
);

class SelectedColorNotifier extends Notifier<int> {
  /// Default starting colour. Black is high-contrast on the dark
  /// canvas background and is in the quick strip.
  static const int _initialIndex = 8;

  @override
  int build() => _initialIndex;

  /// Set the active palette index. Out-of-range inputs are rejected
  /// silently so the UI can't accidentally pick a reserved or
  /// unknown index — the wire codec would drop the resulting paint
  /// anyway, but this keeps the state honest.
  ///
  /// Also pushes the chosen index into [recentColorsProvider] so the
  /// palette sheet's "recent" rail reflects what the user actually
  /// painted with, not just what they hovered.
  void select(int paletteIndex) {
    if (paletteIndex < 0 || paletteIndex > SocialMeshPalette.maxIndex) return;
    state = paletteIndex;
    ref.read(recentColorsProvider.notifier).push(paletteIndex);
  }
}

/// Most-recently-used palette indices, newest first. Capped at
/// [RecentColorsNotifier.maxRecents] entries. In-session only in S7.B
/// — no SharedPreferences yet because the value of "recents survive
/// app restart" is small and the persistence glue would dominate the
/// slice. A later slice can add disk-backed recall without changing
/// any caller.
final recentColorsProvider = NotifierProvider<RecentColorsNotifier, List<int>>(
  RecentColorsNotifier.new,
);

class RecentColorsNotifier extends Notifier<List<int>> {
  /// Soft cap — picked to fit comfortably as a single pinned row at
  /// the top of the palette sheet at any phone width without
  /// horizontal scroll on a 360pt screen.
  static const int maxRecents = 8;

  @override
  List<int> build() => const <int>[];

  /// Insert [paletteIndex] at the head of the recents list. If it
  /// already exists, move-to-front rather than duplicate. Out-of-range
  /// indices are ignored (defence in depth — [SelectedColorNotifier]
  /// already validates).
  void push(int paletteIndex) {
    if (paletteIndex < 0 || paletteIndex > SocialMeshPalette.maxIndex) return;
    final next = <int>[paletteIndex];
    for (final existing in state) {
      if (existing == paletteIndex) continue;
      next.add(existing);
      if (next.length >= maxRecents) break;
    }
    state = next;
  }
}

/// Monotonic per-author op_seq counter for local paints. Local Device
/// Canvas paints never broadcast, so the value doesn't need to
/// survive process death; an in-memory u8 counter is enough for the
/// 6-field dedupe key (CANVAS_V0_1.md §9) to keep two same-second
/// paints distinguishable.
final localCanvasOpSeqProvider =
    NotifierProvider<LocalCanvasOpSeqNotifier, int>(
      LocalCanvasOpSeqNotifier.new,
    );

class LocalCanvasOpSeqNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Return the next op_seq value (mod 256) and advance.
  int takeNext() {
    final next = state;
    state = (state + 1) & 0xFF;
    return next;
  }
}

// ---------------------------------------------------------------------------
// S8: Mesh Canvas send/receive wiring
// ---------------------------------------------------------------------------

/// Feature-level 250 B / 60 s outbound airtime governor (§S0.rate.9
/// of CANVAS_V0_1.md). Lives for the app's lifetime — the budget is
/// per-device, not per-session.
final canvasOutboundGovernorProvider = Provider<CanvasOutboundGovernor>((ref) {
  return CanvasOutboundGovernor();
});

/// Production binding from the canvas send pipeline to ProtocolService
/// via the SIP rate limiter. The coordinator hands this an encoded
/// canvas payload; this adapter wraps it in MRRP + SIP, pre-accounts
/// against the SIP limiter, and ships it through
/// `protocol.sendSipGated(channelIndex:)`.
final canvasOutboundChannelProvider = Provider<ProductionCanvasOutboundChannel>(
  (ref) {
    final protocol = ref.read(protocolServiceProvider);
    final sipLimiter = ref.read(sipRateLimiterProvider);
    return ProductionCanvasOutboundChannel(
      sender: ProtocolServiceCanvasSipSender(protocol),
      sipRateLimiter: sipLimiter,
    );
  },
);

/// Drains `pending_op` rows, batches them, and ships them through the
/// canvas governor → SIP limiter → wire. The viewer's paint handler
/// kicks a drain after every mesh-canvas paint; this provider also
/// schedules a 5-second tick to flush ops that prior drains had to
/// back off on (governor or SIP limiter at capacity).
final canvasSendCoordinatorProvider = FutureProvider<CanvasSendCoordinator>((
  ref,
) async {
  final repo = await ref.watch(canvasRepositoryProvider.future);
  final governor = ref.read(canvasOutboundGovernorProvider);
  final outbound = ref.read(canvasOutboundChannelProvider);
  final coordinator = CanvasSendCoordinator(
    repository: repo,
    governor: governor,
    outbound: outbound,
    localNodeNumProvider: () => ref.read(myNodeNumProvider),
    // Participation gate (CANVAS_PARTICIPATION_V0_1.md §5.3): drain()
    // skips silently when the user has not opted into mesh
    // participation. Rows stay in `pending_op` and resume on the
    // next drain after re-enable.
    canSend: () => ref.read(meshCanvasParticipationEnabledProvider),
  );
  return coordinator;
});

/// S9: sync coordinator. Owns the per-peer-per-tile state machine,
/// digest emit on viewer mount, sync_request scheduling, and the
/// sync_response apply path. Routed inbound by [MrrpServiceCanvas].
final canvasSyncCoordinatorProvider = FutureProvider<CanvasSyncCoordinator>((
  ref,
) async {
  final repo = await ref.watch(canvasRepositoryProvider.future);
  final outbound = ref.read(canvasOutboundChannelProvider);
  final governor = ref.read(canvasOutboundGovernorProvider);
  final coordinator = CanvasSyncCoordinator(
    repository: repo,
    outbound: outbound,
    governor: governor,
    canEmit: () => ref.read(meshCanvasParticipationEnabledProvider),
    onCellApplied: (canvasLocalId) {
      ref.invalidate(canvasCellsProvider(canvasLocalId));
      ref.invalidate(canvasListProvider);
    },
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Decoder + repository-apply layer for inbound canvas frames. The
/// production attach hook in [canvasProtocolWiringProvider] funnels
/// every inbound canvas payload from ProtocolService through this
/// handler's `applyInbound`.
final mrrpServiceCanvasProvider = FutureProvider<MrrpServiceCanvas>((
  ref,
) async {
  final repo = await ref.watch(canvasRepositoryProvider.future);
  final presenceCache = ref.watch(presenceCacheProvider);
  final syncCoordinator = await ref.watch(canvasSyncCoordinatorProvider.future);
  return MrrpServiceCanvas(
    repository: repo,
    presenceCache: presenceCache,
    syncCoordinator: syncCoordinator,
    // Source the configured Meshtastic channel name so an auto-create
    // triggered by an inbound paint frame names the canvas correctly
    // (e.g. "Primary", "TestChannel") instead of the placeholder
    // "Canvas $channelIndex". Without this hook the placeholder
    // persists forever because nothing else renames it. Read (not
    // watch) so service identity is stable; channel name changes
    // post-create do not retroactively rename the canvas row.
    channelNameForFallback: (channelIndex) {
      final channels = ref.read(channelsProvider);
      for (final c in channels) {
        if (c.index == channelIndex && c.name.isNotEmpty) {
          return c.name;
        }
      }
      return null;
    },
    // Fires once per inbound frame when at least one op landed. Without
    // this, cells write to SQLite but no viewer rebuilds: the user only
    // sees inbound paints after their own next tap kicks an invalidate.
    // canvasListProvider is invalidated alongside the cell stream so
    // last_op_at_ms ordering, cell_count, and the latent->live
    // transition all repaint on the overview in the same pass.
    onCellApplied: (canvasLocalId) {
      ref.invalidate(canvasCellsProvider(canvasLocalId));
      ref.invalidate(canvasListProvider);
    },
    // Inbound presence updates the cache directly; the cache's own
    // changeStream drives canvasPresenceProvider re-emission, so no
    // explicit ref.invalidate is needed here.
  );
});

/// Side-effect provider: attaches the inbound canvas handler to
/// ProtocolService and tears it down when this provider is disposed.
/// Materialised by the canvas overview screen on first build so the
/// app does not pay the wiring cost when the user never opens the
/// feature. After the first watch, the hook stays attached for the
/// app's lifetime (the provider container outlives the screen).
///
/// Also force-materialises [sipDiscoveryProvider]. ProtocolService
/// buffers every inbound SIP frame in a 16-entry startup queue
/// until `attachSipDiscovery` is called — and `sipDiscoveryProvider`
/// is what calls it. Without this watch the canvas frames arrive
/// at the iPhone, get parked in the startup buffer, and never reach
/// the canvas demux because nothing else on the MeshCanvas surface
/// would have caused the SIP stack to attach.
final canvasProtocolWiringProvider = FutureProvider<void>((ref) async {
  final protocol = ref.read(protocolServiceProvider);
  final mrrpService = await ref.watch(mrrpServiceCanvasProvider.future);
  // Force SIP discovery to materialise so the startup buffer drains
  // and inbound canvas frames stop being parked pre-attach.
  ref.watch(sipDiscoveryProvider);
  protocol.attachCanvasInbound((
    int senderNodeId,
    int channelIndex,
    payload,
  ) async {
    await mrrpService.applyInbound(
      canvasPayload: payload,
      senderNodeId: senderNodeId,
      channelIndex: channelIndex,
    );
  });
  ref.onDispose(() {
    protocol.attachCanvasInbound(null);
  });
  AppLogging.meshCanvas('canvas inbound hook attached to ProtocolService');
});

// ---------------------------------------------------------------------------
// Latent channel canvases (S8 activation-model correction)
// ---------------------------------------------------------------------------

/// One Meshtastic-channel-bound canvas row for the overview Mesh tab.
///
/// Every configured channel produces one of these, whether or not a
/// canvas row exists yet in the local `canvas` table. Two states:
///
///   - **Dormant** (`materialised` is null): no canvas row in the
///     local DB yet, no peer activity heard. The overview renders a
///     "No paints yet - seed the first pixel" copy. Tapping the row
///     calls `repo.getOrCreateMeshCanvas(canvasId, channelIndex,
///     name)` and pushes the viewer — the canvas row is only
///     persisted at first interaction, NOT eagerly at app boot.
///
///   - **Live** (`materialised` set): a canvas row already exists,
///     either because the local user has painted or because a peer's
///     paint frame arrived. The overview renders the cell count +
///     last-activity hint.
///
/// The key insight: the channel IS the canvas. We never wait for
/// discovery before showing a row. CANVAS_V0_1.md §3 makes the
/// derivation deterministic — both sides compute the same
/// `canvas_id` independently from `(channel_psk, canvas_name)`.
class LatentChannelCanvas {
  final int channelIndex;
  final String channelName;
  final int canvasId;

  /// The materialised canvas row, if one exists. Null until first
  /// paint (local or inbound from a peer).
  final CanvasSummary? materialised;

  const LatentChannelCanvas({
    required this.channelIndex,
    required this.channelName,
    required this.canvasId,
    required this.materialised,
  });

  /// Whether any paint has ever landed on this canvas — used by the
  /// overview to switch between dormant + active row copy.
  bool get isDormant => materialised == null || materialised!.cellCount == 0;
}

/// All channel-bound mesh canvases visible in the overview's Mesh tab.
///
/// Source of truth is `channelsProvider` (the configured Meshtastic
/// channels). For each channel we compute the canonical `canvas_id`
/// via [deriveCanvasIdFromChannel] and merge in any matching
/// `canvas` table row from [canvasListProvider]. Channels without a
/// table row appear as dormant entries — the user can still tap them
/// to seed a paint.
///
/// Ordering: by channel index ascending (Primary first, then 1..7).
final latentChannelCanvasesProvider = FutureProvider<List<LatentChannelCanvas>>(
  (ref) async {
    final channels = ref.watch(channelsProvider);
    final canvases = await ref.watch(canvasListProvider.future);
    final byKey = <(int, int), CanvasSummary>{
      for (final c in canvases)
        if (c.scope == CanvasScope.mesh && c.channelIndex != null)
          (c.channelIndex!, c.canvasId): c,
    };

    final result = <LatentChannelCanvas>[];
    for (final channel in channels) {
      // Channel name defaults to "Primary" for index 0 when the
      // firmware reports an empty name. The same default is used
      // on the receive side, so both sides compute matching ids.
      final name = _channelDisplayName(channel);
      final canvasId = deriveCanvasIdFromChannel(
        channelPsk: channel.psk,
        canvasName: name,
      );
      result.add(
        LatentChannelCanvas(
          channelIndex: channel.index,
          channelName: name,
          canvasId: canvasId,
          materialised: byKey[(channel.index, canvasId)],
        ),
      );
    }
    result.sort((a, b) => a.channelIndex.compareTo(b.channelIndex));
    return result;
  },
);

/// Display name for a [ChannelConfig] when building a channel-bound
/// canvas row. Index 0 with an empty firmware name renders as
/// "Primary" to match Meshtastic UX conventions; everything else
/// uses the configured name verbatim. Pure so the canvas_id
/// derivation stays deterministic per (psk, name).
String _channelDisplayName(ChannelConfig channel) {
  if (channel.name.isNotEmpty) return channel.name;
  if (channel.index == 0) return 'Primary'; // lint-allow: hardcoded-string
  return 'Channel ${channel.index}'; // lint-allow: hardcoded-string
}
