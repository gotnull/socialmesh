// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Single-canvas viewer screen. Renamed from
// mesh_canvas_placeholder_screen.dart in S7.C when the overview list
// became the entry point.
//
// Scope: renders the r/place-style viewer for ONE canvas. The
// caller (the overview screen) decides which canvas to show and
// passes it in via the constructor. Local Device Canvas paints
// land directly via the local repo path; mesh canvas send wiring
// arrives in S7-final.
//
// Layout contract (load-bearing for S7.A interaction acceptance):
//
//   1) The screen is a STABLE SHELL:
//        - app bar (fixed; lives in GlassScaffold)
//        - canvas viewport (Padding + ClipRRect + DecoratedBox frame)
//            - InteractiveViewer wraps ONLY the canvas board
//        - bottom colour strip (fixed; sibling of Expanded)
//
//   2) The outer CustomScrollView produced by GlassScaffold MUST be
//      non-scrollable in this screen — otherwise drag gestures that
//      escape the InteractiveViewer's recognizer bubble up to the
//      scroll view and rubber-band the entire body. Passing
//      [NeverScrollableScrollPhysics] disables that bubble path.
//
//   3) The canvas board sits inside a visible inset frame so the
//      user can see "this rectangle is the viewport; the canvas is
//      sliding inside it."
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_providers.dart';

import '../../../core/canvas/canvas_palette.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/canvas/canvas_models.dart';
import '../../../services/haptic_service.dart';
import '../providers/mesh_canvas_providers.dart';
import '../widgets/canvas_color_strip.dart';
import '../widgets/canvas_help_sheet.dart';
import '../widgets/canvas_hud_overlays.dart';
import '../widgets/canvas_palette_sheet.dart';
import '../widgets/canvas_tile_inspector_sheet.dart';
import '../widgets/canvas_viewer.dart';

class MeshCanvasViewerScreen extends ConsumerWidget {
  /// Canvas to render. The overview screen passes one of its list
  /// entries here; the viewer does not lookup or auto-create.
  final CanvasSummary canvas;

  const MeshCanvasViewerScreen({super.key, required this.canvas});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassScaffold(
      // Use the canvas's user-visible name so the viewer's title
      // reflects what the user picked from the overview list. The
      // generic "MeshCanvas" brand lives on the overview screen.
      title: canvas.name,
      // Disable outer scroll so a drag that escapes the InteractiveViewer
      // can never rubber-band the body. The viewer + strip together
      // already fill the viewport; nothing else needs to scroll.
      physics: const NeverScrollableScrollPhysics(),
      actions: [
        IconButton(
          // Canonical app-bar help icon used across the app (see
          // meshcore_repeater_cli_screen.dart). Pairs with the
          // tooltip + glass HelpSheet below.
          key: const ValueKey('mesh-canvas-help'),
          tooltip: context.l10n.meshCanvasHelpTooltip,
          icon: const Icon(Icons.help_outline_rounded),
          onPressed: () {
            ref.haptics.buttonTap();
            showCanvasHelpSheet(context: context);
          },
        ),
      ],
      slivers: [
        SliverFillRemaining(
          hasScrollBody: true,
          child: _MeshCanvasViewBody(canvas: canvas),
        ),
      ],
    );
  }
}

class _MeshCanvasViewBody extends ConsumerWidget {
  final CanvasSummary canvas;

  const _MeshCanvasViewBody({required this.canvas});

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
      // Mesh Canvas: enqueue into `pending_op` AND apply to local
      // `cell` / `applied_op` (the repository handles both inside one
      // transaction). The local node_num is the real author for mesh
      // canvases — receivers use it for LWW conflict resolution.
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
        // Kick the send coordinator — it will respect both the
        // canvas governor and the SIP rate limiter, so worst case is
        // the row sits in pending_op until the next drain.
        final coordinator = (await ref.read(
          canvasSendCoordinatorProvider.future,
        ));
        // Fire-and-forget; the coordinator logs its own outcome.
        unawaited(coordinator.drain());
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
    final haptics = ref.haptics;
    haptics.longPress();
    await showCanvasTileInspectorSheet(
      context: context,
      canvas: canvas,
      x: x,
      y: y,
    );
  }

  /// Open the full 64-colour palette sheet from the strip's "More"
  /// button. On a non-null pop result, applies the choice via
  /// [SelectedColorNotifier.select] (which also pushes to
  /// [recentColorsProvider]) and fires the selection haptic.
  Future<void> _onMore({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    // Capture every ref-derived handle BEFORE the await. Touching
    // `ref` again after the sheet pops is async-unsafe because the
    // host widget may have unmounted in the meantime.
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cellsAsync = ref.watch(canvasCellsProvider(canvas.localId));
    final selectedColor = ref.watch(selectedColorProvider);

    final cells = cellsAsync.asData?.value ?? const <CanvasCell>[];

    // Layered background: a slightly-darker outer pane sits under the
    // viewer to give depth separation from the surrounding chrome,
    // while the painter draws the canvas surface (lighter tone) +
    // chunk lattice + ring on top of that. Keeps things flat enough
    // to read as "pixels on a wall", not skeuomorphic.
    final outsidePane = context.background;
    const canvasSurface = Color(0xFF161A22);
    const chunkLine = Color(0x14FFFFFF);
    const surfaceRing = Color(0x66FFFFFF);
    final frameBorder = context.textTertiary.withValues(alpha: 0.18);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing12,
              AppTheme.spacing16,
              AppTheme.spacing12,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radius16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      outsidePane,
                      Color.lerp(outsidePane, canvasSurface, 0.18) ??
                          outsidePane,
                    ],
                  ),
                  border: Border.all(color: frameBorder, width: 0.6),
                  borderRadius: BorderRadius.circular(AppTheme.radius16),
                ),
                // Stack: viewer fills the frame; HUD + identity chip
                // are positioned overlays. Both overlays sit OUTSIDE
                // the InteractiveViewer subtree so they do not pan,
                // scale, or jitter with the canvas transform. They
                // are visually inside the framed viewport (which is
                // the right place for "what canvas am I on" and
                // "what colour am I painting with") but architecturally
                // they are chrome.
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
                        onTapPaint: (x, y) =>
                            _onTapPaint(context: context, ref: ref, x: x, y: y),
                        onLongPressInspect: (x, y) => _onLongPressInspect(
                          context: context,
                          ref: ref,
                          x: x,
                          y: y,
                        ),
                      ),
                    ),
                    Positioned(
                      top: AppTheme.spacing12,
                      left: AppTheme.spacing12,
                      child: IgnorePointer(
                        // IgnorePointer so the chip never steals a tap
                        // that was aiming for the canvas surface beneath.
                        child: CanvasIdentityChip(
                          icon: Icons.smartphone_outlined,
                          label: context.l10n.meshCanvasIdentityLocal,
                          subtitle:
                              context.l10n.meshCanvasIdentityLocalSubtitle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: AppTheme.spacing12,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: CanvasColorHud(
                            paletteIndex: selectedColor,
                            eraserLabel: context.l10n.meshCanvasHudEraserLabel,
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
        // CanvasColorStrip is a SIBLING of Expanded — it is part of
        // the chrome and is intentionally NOT under InteractiveViewer.
        // The strip MUST stay perfectly still during pan / pinch /
        // zoom of the canvas; that invariant is regression-pinned by
        // a widget test (canvas_strip_chrome_containment_test).
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
  }
}
