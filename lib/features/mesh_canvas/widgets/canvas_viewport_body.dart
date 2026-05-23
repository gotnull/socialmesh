// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Shared canvas viewport body. Renders one canvas's CanvasViewer +
// HUD overlays + bottom colour strip in a stable shell. Used by:
//
//   - [MeshCanvasOverviewScreen]'s Local tab (renders the Local
//     Device Canvas inline — there is no card list / push step
//     because the local sandbox is singular).
//   - [MeshCanvasViewerScreen] (renders ONE mesh canvas after the
//     overview's channel list pushes the screen).
//
// IA invariant: the identity-chip overlay is shown ONLY for the
// Local Device Canvas. Mesh canvases get NO identity chip — the
// channel name lives in the app bar on [MeshCanvasViewerScreen],
// and adding a redundant chip ("Local Device Canvas" leaking onto
// a mesh canvas) was the AI-slop drift that triggered the S8 IA
// rework.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/canvas/canvas_palette.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../providers/app_providers.dart';
import '../../../services/canvas/canvas_constants.dart';
import '../../../services/canvas/canvas_models.dart';
import '../../../services/canvas/presence_emit_coordinator.dart';
import '../../../services/haptic_service.dart';
import '../providers/mesh_canvas_participation_providers.dart';
import '../providers/mesh_canvas_providers.dart';
import '../providers/presence_providers.dart';
import 'canvas_color_strip.dart';
import 'canvas_hud_overlays.dart';
import 'canvas_palette_sheet.dart';
import 'canvas_presence_strip.dart';
import 'canvas_tile_inspector_sheet.dart';
import 'canvas_viewer.dart';

class CanvasViewportBody extends ConsumerWidget {
  /// Canvas to render. The caller decides which canvas to show and
  /// passes it in; this widget never looks up or auto-creates.
  final CanvasSummary canvas;

  const CanvasViewportBody({super.key, required this.canvas});

  Future<void> _onTapPaint({
    required BuildContext context,
    required WidgetRef ref,
    required int x,
    required int y,
  }) async {
    final selectedColor = ref.read(selectedColorProvider);
    final opSeq = ref.read(localCanvasOpSeqProvider.notifier).takeNext();
    final opTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final repoAsync = ref.read(canvasRepositoryProvider);
    final repo = repoAsync.asData?.value;
    if (repo == null) {
      AppLogging.meshCanvas(
        'tap paint skipped: repository not ready (canvas=${canvas.localId})',
      );
      return;
    }

    final bool accepted;
    if (canvas.scope == CanvasScope.local) {
      // Local Device Canvas: author is informational only (never
      // broadcasts), so a constant 0 is fine. paintLocal applies to
      // `cell` + `applied_op` (direction=outbound) and never touches
      // `pending_op`.
      accepted = await repo.paintLocal(
        canvasLocalId: canvas.localId,
        x: x,
        y: y,
        color: selectedColor,
        authorNodeNum: 0,
        opTs: opTs,
        opSeq: opSeq,
      );
    } else {
      // Mesh Canvas: defence-in-depth participation gate. The Mesh
      // tab in the overview hides the channel list when participation
      // is off, but a deep-link / programmatic push could otherwise
      // surface this viewer. Hard-block enqueue here so no
      // `pending_op` row can land while participation is disabled.
      // See docs/canvas/CANVAS_PARTICIPATION_V0_1.md §5.3.
      final participationEnabled = ref.read(
        meshCanvasParticipationEnabledProvider,
      );
      if (!participationEnabled) {
        AppLogging.meshCanvas(
          'mesh paint blocked: participation disabled '
          '(canvas=${canvas.localId})',
        );
        return;
      }
      // Mesh Canvas: enqueue into `pending_op` AND apply to local
      // `cell` / `applied_op` in one transaction. The local node_num
      // is the real author for mesh canvases — receivers use it for
      // LWW conflict resolution.
      final authorNodeNum = ref.read(myNodeNumProvider);
      if (authorNodeNum == null) {
        AppLogging.meshCanvas(
          'tap paint skipped: my node num unknown (canvas=${canvas.localId})',
        );
        return;
      }
      accepted = await repo.enqueuePaint(
        canvasLocalId: canvas.localId,
        x: x,
        y: y,
        color: selectedColor,
        authorNodeNum: authorNodeNum,
        opTs: opTs,
        opSeq: opSeq,
      );
      if (accepted) {
        // Kick the send coordinator — it respects both the canvas
        // governor and the SIP rate limiter, so worst case is the
        // row sits in pending_op until the next drain.
        final coordinator = await ref.read(
          canvasSendCoordinatorProvider.future,
        );
        unawaited(coordinator.drain());
        // Refresh local self to painting + try the wire emit (subject
        // to the canvas governor headroom + paint queue + SIP gates).
        unawaited(_notifyPresencePaintEnqueued(ref));
      }
    }
    if (accepted) {
      // The toggle haptic is the lightest in the catalog — picked
      // because every cell tap fires one and a heavier pulse would
      // get tiring fast on a long paint session.
      ref.haptics.toggle();
      ref.invalidate(canvasCellsProvider(canvas.localId));
    } else {
      AppLogging.meshCanvas(
        'tap paint rejected by LWW at ($x,$y) canvas=${canvas.localId}',
      );
    }
  }

  Future<void> _onLongPressInspect({
    required BuildContext context,
    required WidgetRef ref,
    required int x,
    required int y,
  }) async {
    AppLogging.meshCanvas(
      'long-press inspect at ($x,$y) canvas=${canvas.localId}',
    );
    ref.haptics.longPress();
    // Long-press counts as active engagement with the canvas surface;
    // refresh local self toward `active` (subject to cache
    // no-downgrade + presence throttles + anti-starvation gates).
    unawaited(_notifyPresenceInteraction(ref));
    await showCanvasTileInspectorSheet(
      context: context,
      canvas: canvas,
      x: x,
      y: y,
    );
  }

  /// Presence-emitter helper. Mesh-scope only — local canvas never
  /// emits presence (P8). Resolves the coordinator and notifies
  /// painting; if the coordinator is not ready (link not up, etc.),
  /// fail silently.
  Future<void> _notifyPresencePaintEnqueued(WidgetRef ref) async {
    if (canvas.scope != CanvasScope.mesh) return;
    if (canvas.canvasId == kLocalCanvasIdSentinel) return;
    final asyncCoord = ref.read(presenceEmitCoordinatorProvider);
    final coordinator = asyncCoord.asData?.value;
    if (coordinator == null) return;
    await coordinator.notifyPaintEnqueued(canvas.localId);
  }

  /// Presence-emitter helper for active interactions (long-press,
  /// palette tap). Same mesh-scope guard as the paint notifier.
  Future<void> _notifyPresenceInteraction(WidgetRef ref) async {
    if (canvas.scope != CanvasScope.mesh) return;
    if (canvas.canvasId == kLocalCanvasIdSentinel) return;
    final asyncCoord = ref.read(presenceEmitCoordinatorProvider);
    final coordinator = asyncCoord.asData?.value;
    if (coordinator == null) return;
    await coordinator.notifyInteraction(canvas.localId);
  }

  /// Open the full 64-colour palette sheet from the strip's "More"
  /// button. On a non-null pop result, applies the choice via
  /// [SelectedColorNotifier.select] (which also pushes to
  /// [recentColorsProvider]) and fires the selection haptic.
  Future<void> _onMore({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final selectedIndex = ref.read(selectedColorProvider);
    final recents = ref.read(recentColorsProvider);
    final recentLabel = context.l10n.meshCanvasRecentLabel;
    final selectedColorNotifier = ref.read(selectedColorProvider.notifier);
    final haptics = ref.haptics;

    final picked = await showCanvasPaletteSheet(
      context: context,
      selectedIndex: selectedIndex,
      recentIndices: recents,
      recentLabel: recentLabel,
    );
    if (picked == null) return;
    selectedColorNotifier.select(picked);
    haptics.itemSelect();
    unawaited(_notifyPresenceInteraction(ref));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cellsAsync = ref.watch(canvasCellsProvider(canvas.localId));
    final selectedColor = ref.watch(selectedColorProvider);

    final cells = cellsAsync.asData?.value ?? const <CanvasCell>[];

    final outsidePane = context.background;
    const canvasSurface = Color(0xFF161A22);
    const chunkLine = Color(0x14FFFFFF);
    const surfaceRing = Color(0x66FFFFFF);

    // Identity chip is intentionally Local-only. Mesh canvases carry
    // their identity in the app bar title (the channel name) — adding
    // a chip would imply the mesh canvas is somehow "owned by Local",
    // which it isn't.
    final showLocalIdentityChip = canvas.scope == CanvasScope.local;
    final isMeshScope = canvas.scope == CanvasScope.mesh;

    final column = Column(
      children: [
        // Canvas vitals header — mirrors the channel card's stat
        // density into the viewer surface. Anchored chrome (not a
        // floating chip), small-caps monospace, accent rail on the
        // left. Bridges the visual identity between the overview
        // channel card and the live board.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing12,
            AppTheme.spacing16,
            0,
          ),
          child: _CanvasVitalsBar(canvas: canvas, paintedCount: cells.length),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing12,
              AppTheme.spacing16,
              AppTheme.spacing12,
            ),
            // Canvas frame chrome — same gradient-border + depth-
            // blend as the Mesh tab channel cards (consistency
            // across the feature). Accent presence is the bridge
            // between the channel card and the live board.
            child: GradientBorderContainer(
              borderRadius: AppTheme.radius16,
              borderWidth: 1.0,
              accentOpacity: 0.11,
              enableDepthBlend: true,
              depthBlendOpacity: 0.02,
              backgroundColor: outsidePane,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius16 - 1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color.lerp(outsidePane, canvasSurface, 0.10) ??
                            outsidePane,
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CanvasViewer(
                          cells: cells,
                          palette: SocialMeshPalette.colors,
                          widthCells: canvas.width,
                          heightCells: canvas.height,
                          outsideColor: outsidePane,
                          surfaceColor: canvasSurface,
                          chunkLineColor: chunkLine,
                          borderColor: surfaceRing,
                          onTapPaint: (x, y) => _onTapPaint(
                            context: context,
                            ref: ref,
                            x: x,
                            y: y,
                          ),
                          onLongPressInspect: (x, y) => _onLongPressInspect(
                            context: context,
                            ref: ref,
                            x: x,
                            y: y,
                          ),
                        ),
                      ),
                      if (showLocalIdentityChip)
                        Positioned(
                          top: AppTheme.spacing12,
                          left: AppTheme.spacing12,
                          child: IgnorePointer(
                            // IgnorePointer so the chip never steals a tap
                            // that was aiming for the canvas beneath.
                            child: CanvasIdentityChip(
                              icon: Icons.smartphone_outlined,
                              label: context.l10n.meshCanvasIdentityLocal,
                              subtitle:
                                  context.l10n.meshCanvasIdentityLocalSubtitle,
                            ),
                          ),
                        ),
                      // Mesh-scope only: presence strip + emit-coordinator
                      // lifecycle host. The host is an invisible
                      // ConsumerStatefulWidget that owns the
                      // attach/detach hooks; the strip self-hides when
                      // there are zero remote peers.
                      // Mesh-scope: presence strip at top-left of the
                      // canvas surface, where the local-canvas identity
                      // chip would otherwise sit. Strip self-hides when
                      // there are no remote peers. Lifecycle host (which
                      // owns attach/detach) is mounted OUTSIDE the
                      // Stack, below.
                      if (canvas.scope == CanvasScope.mesh)
                        Positioned(
                          top: AppTheme.spacing12,
                          left: AppTheme.spacing12,
                          child: CanvasPresenceStrip(
                            canvasLocalId: canvas.localId,
                          ),
                        ),
                      // Atmospheric "first paint wakes the board"
                      // prompt — center of the canvas frame, visible
                      // only while there are zero painted cells.
                      // Disappears the moment a real cell lands.
                      // IgnorePointer so the tap goes through to the
                      // canvas's GestureDetector.
                      if (cells.isEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _CanvasEmptyPrompt(
                              isMeshScope: canvas.scope == CanvasScope.mesh,
                            ),
                          ),
                        ),
                      // (Floating gesture-hint chip strip removed —
                      // four ambient chips at varying positions read
                      // as clutter, not affordance. The app bar (i)
                      // icon + empty-canvas prompt + help sheet are
                      // the explanation surface. /r/place principle
                      // 17: "minimal mechanics, maximal emergence.")
                      Positioned(
                        bottom: AppTheme.spacing12,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Center(
                            child: CanvasColorHud(
                              paletteIndex: selectedColor,
                              eraserLabel:
                                  context.l10n.meshCanvasHudEraserLabel,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // CanvasColorStrip is a SIBLING of Expanded — chrome, NOT
        // under InteractiveViewer. The strip MUST stay perfectly
        // still during pan / pinch / zoom; regression-pinned by
        // canvas_strip_chrome_containment_test.
        CanvasColorStrip(
          selectedIndex: selectedColor,
          onSelect: (paletteIndex) {
            ref.read(selectedColorProvider.notifier).select(paletteIndex);
            ref.haptics.itemSelect();
          },
          onMore: () => _onMore(context: context, ref: ref),
        ),
      ],
    );

    // Wrap the column in the presence lifecycle host for mesh
    // canvases. Wrapping (rather than mounting inside the Stack)
    // keeps the host OUT of the canvas hit-test path — even
    // a 0-size Stack child can subtly disrupt InteractiveViewer
    // gesture routing, which broke S8 paint dispatch tests during
    // P5 bring-up.
    if (isMeshScope) {
      return _PresenceLifecycleHost(canvas: canvas, child: column);
    }
    return column;
  }
}

/// Transparent wrapper that owns the MeshCanvas presence emitter
/// lifecycle.
///
/// Mounting this widget:
///   - schedules the initial viewing wire emit via the presence emit
///     coordinator (after the first frame);
///   - synchronously seeds the local self entry in the cache via the
///     coordinator's attachViewer path;
///   - on dispose, best-effort detaches the viewer (which evicts
///     self and emits a `leaving` frame iff a prior emit succeeded).
///
/// Renders [child] unchanged. By WRAPPING the viewer column instead
/// of mounting as a separate Stack child, we keep this host out of
/// the canvas hit-test path — early P5 bring-up showed that even a
/// 0-size sibling in the canvas Stack can subtly disrupt the
/// InteractiveViewer's tap routing.
class _PresenceLifecycleHost extends ConsumerStatefulWidget {
  final CanvasSummary canvas;
  final Widget child;

  const _PresenceLifecycleHost({required this.canvas, required this.child});

  @override
  ConsumerState<_PresenceLifecycleHost> createState() =>
      _PresenceLifecycleHostState();
}

class _PresenceLifecycleHostState extends ConsumerState<_PresenceLifecycleHost>
    with LifecycleSafeMixin<_PresenceLifecycleHost> {
  PresenceEmitCoordinator? _coordinator;

  @override
  void initState() {
    super.initState();
    final canvas = widget.canvas;
    if (canvas.scope != CanvasScope.mesh) return;
    if (canvas.canvasId == kLocalCanvasIdSentinel) return;
    final channelIndex = canvas.channelIndex;
    if (channelIndex == null) return;

    // Note on heartbeats: there is intentionally NO recurring Timer
    // here. Heartbeats are activity-driven (notifyInteraction /
    // notifyPaintEnqueued in the parent widget refresh the local
    // self entry and attempt wire emits). Pure-idle viewers fade
    // from peers naturally after the 180 s TTL elapses; the next
    // interaction re-emits. Avoiding a long-lived periodic also
    // keeps flutter_test's `_verifyInvariants` happy without
    // requiring every viewer test to override providers.

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final coordinator = await ref.read(
        presenceEmitCoordinatorProvider.future,
      );
      if (!mounted) return;
      _coordinator = coordinator;
      await coordinator.attachViewer(
        canvasLocalId: canvas.localId,
        channelIndex: channelIndex,
        canvasId: canvas.canvasId,
      );
    });
  }

  @override
  void dispose() {
    final coordinator = _coordinator;
    if (coordinator != null) {
      // Best-effort detach. dispose() is synchronous so we cannot
      // await; the coordinator's detach path is itself async but the
      // synchronous parts (session remove, cache evict) run first.
      unawaited(coordinator.detachViewer(widget.canvas.localId));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Centered atmospheric prompt shown on a fresh canvas with zero
/// painted cells. /r/place principle 5 ("dormant space implies
/// opportunity") + principle 18 ("empty states must feel latent,
/// not dead"). Mounted as an IgnorePointer child of the canvas
/// Stack so it never blocks a tap — the first tap drops a pixel
/// and the prompt vanishes by data.
class _CanvasEmptyPrompt extends StatelessWidget {
  /// `true` for a Mesh canvas (uses the seed-the-board copy);
  /// `false` for the Local Device Canvas (uses the private-sandbox
  /// copy).
  final bool isMeshScope;

  const _CanvasEmptyPrompt({required this.isMeshScope});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = isMeshScope
        ? l.meshCanvasViewerEmptyMeshTitle
        : l.meshCanvasViewerEmptyLocalTitle;
    final subtitle = isMeshScope
        ? l.meshCanvasViewerEmptyMeshSubtitle
        : l.meshCanvasViewerEmptyLocalSubtitle;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: context.textPrimary.withValues(alpha: 0.85),
              letterSpacing: 0.3,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: context.textTertiary.withValues(alpha: 0.85),
              letterSpacing: 0.4,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

/// Canvas vitals header strip rendered above the canvas frame.
///
/// Composition (left to right):
///   - Scope rail: a thin accent bar + uppercase scope badge
///     (MESH CANVAS / LOCAL SANDBOX). Identity tier — answers
///     "what surface am I on?" without duplicating the app bar's
///     channel name.
///   - Dimensions stat: "128 × 128" in tertiary monospace.
///   - Spacer.
///   - Painted stat: cumulative non-default cell count. Accent
///     tint when > 0 so the eye lands here first as the canvas
///     fills up.
///   - Live / quiet pill: mesh-scope only. Counts remote peers
///     from [presenceCountProvider]; reads "QUIET" when zero so
///     the strip never looks broken on an idle canvas.
///
/// All copy is uppercased small-caps JetBrainsMono, letter-spaced
/// for status-line readability. Anchored chrome — never floats.
class _CanvasVitalsBar extends ConsumerWidget {
  final CanvasSummary canvas;
  final int paintedCount;

  const _CanvasVitalsBar({required this.canvas, required this.paintedCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final accent = context.accentColor;
    final isMesh = canvas.scope == CanvasScope.mesh;
    final hasPaint = paintedCount > 0;

    final scopeLabel = isMesh
        ? l.meshCanvasVitalsScopeMesh
        : l.meshCanvasVitalsScopeLocal;
    final dimensions = l.meshCanvasVitalsDimensions(
      canvas.width,
      canvas.height,
    );
    final paintedLabel = l.meshCanvasVitalsPainted(paintedCount);

    // Live-peer pill (mesh only). Reads remote-peer count from the
    // presence selector so we never count self.
    Widget? livePill;
    if (isMesh) {
      final counts = ref.watch(presenceCountProvider(canvas.localId));
      final total = counts.total;
      livePill = _VitalsPill(
        label: total > 0
            ? l.meshCanvasVitalsLive(total)
            : l.meshCanvasVitalsQuiet,
        color: total > 0 ? accent : context.textTertiary,
        glow: total > 0,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing12,
        AppTheme.spacing8,
        AppTheme.spacing10,
        AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        // Background: ~3% accent wash on the left fading to a
        // neutral card surface on the right. Mirrors the channel
        // card's depth-blend so the two surfaces read as siblings.
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            accent.withValues(alpha: 0.05),
            context.card.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: accent.withValues(alpha: 0.10), width: 0.5),
      ),
      child: Row(
        children: [
          // Identity rail: thin accent bar + scope badge.
          Container(
            width: AppTheme.spacing2,
            height: AppTheme.spacing14,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(AppTheme.spacing1),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            scopeLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: accent.withValues(alpha: 0.85),
              letterSpacing: 1.2,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          // Subtle divider dot between identity and dimensions.
          Container(
            width: AppTheme.spacing2,
            height: AppTheme.spacing2,
            decoration: BoxDecoration(
              color: context.textTertiary.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(AppTheme.spacing1),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            dimensions,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: context.textTertiary.withValues(alpha: 0.85),
              letterSpacing: 0.8,
              fontFamily: AppTheme.fontFamily,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          Text(
            paintedLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: hasPaint
                  ? accent.withValues(alpha: 0.9)
                  : context.textTertiary.withValues(alpha: 0.75),
              letterSpacing: 1.0,
              fontFamily: AppTheme.fontFamily,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (livePill != null) ...[
            const SizedBox(width: AppTheme.spacing8),
            livePill,
          ],
        ],
      ),
    );
  }
}

/// Trailing live / quiet status pill on the vitals bar. Optional
/// glow so a live count visually pulls the eye without screaming.
class _VitalsPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool glow;

  const _VitalsPill({
    required this.label,
    required this.color,
    required this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: glow
            ? color.withValues(alpha: 0.14)
            : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(
          color: color.withValues(alpha: glow ? 0.35 : 0.18),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color.withValues(alpha: glow ? 1.0 : 0.6),
              shape: BoxShape.circle,
              boxShadow: glow
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: AppTheme.spacing6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1.0,
              fontFamily: AppTheme.fontFamily,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
