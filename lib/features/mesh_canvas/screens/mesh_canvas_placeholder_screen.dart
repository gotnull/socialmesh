// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas entry screen.
//
// S7.A scope: hosts the live r/place-style viewer over the Local
// Device Canvas only (per spec §S0.rate.7 — Local Device Canvas
// allows relaxed / effectively unlimited painting, no broadcast).
//
// S7.B was paused mid-flight (palette sheet / help sheet / HUD /
// identity chip widgets exist in tree but are NOT wired here yet)
// pending sim-verification of the S7.A interaction containment fix
// described below.
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
//      scroll view and rubber-band the entire body, including the
//      strip, producing the "the whole screen moves with my finger"
//      failure mode called out by the developer. Passing
//      [NeverScrollableScrollPhysics] disables that bubble path.
//
//   3) The canvas board sits inside a visible inset frame so the
//      user can see "this rectangle is the viewport; the canvas is
//      sliding inside it." Without the frame the canvas-pixel-space
//      slides under raw screen chrome and feels like the chrome is
//      moving.
//
// File name is still "*_placeholder_screen.dart" for S7.A/S7.B to
// avoid touching `main_shell.dart`'s import; renaming lands in S7.C
// when the overview list takes over the entry point.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/canvas/canvas_palette.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/canvas/canvas_models.dart';
import '../../../services/haptic_service.dart';
import '../providers/mesh_canvas_providers.dart';
import '../widgets/canvas_color_strip.dart';
import '../widgets/canvas_viewer.dart';

class MeshCanvasPlaceholderScreen extends ConsumerWidget {
  const MeshCanvasPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasAsync = ref.watch(localDeviceCanvasProvider);
    return GlassScaffold(
      title: context.l10n.meshCanvasPlaceholderTitle,
      // Disable outer scroll so a drag that escapes the InteractiveViewer
      // can never rubber-band the body. The viewer + strip together
      // already fill the viewport; nothing else needs to scroll.
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: true,
          child: canvasAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => _ErrorBody(error: e),
            data: (canvas) => _MeshCanvasViewBody(canvas: canvas),
          ),
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
    // Local Device Canvas: author is informational only (never
    // broadcasts), so a constant 0 is fine for v0.1. Mesh Canvas
    // paint paths (S7-final) will use the live node_num.
    final accepted = await repo.paintLocal(
      canvasLocalId: canvas.localId,
      x: x,
      y: y,
      color: selectedColor,
      authorNodeNum: 0,
      opTs: opTs,
      opSeq: opSeq,
    );
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

  void _onLongPressInspect({required int x, required int y}) {
    // S7.A leaves the inspector unimplemented. We log the request so
    // sim verification can confirm the long-press hit path. The full
    // AppBottomSheet inspector lands in S7.D.
    AppLogging.meshCanvas(
      'long-press inspect at ($x,$y) — S7.D will surface the sheet',
    );
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
                  onLongPressInspect: (x, y) => _onLongPressInspect(x: x, y: y),
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
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final Object error;
  const _ErrorBody({required this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.textSecondary),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              'Could not load canvas: $error', // lint-allow: hardcoded-string
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
