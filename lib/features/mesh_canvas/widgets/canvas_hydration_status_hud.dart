// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas hydration-status HUD pill (S9).
//
// Spec anchor: docs/canvas/CANVAS_SYNC_V0_1.md §6.1.
//
// Small anchored pill in the canvas viewer's top-right area,
// stacked above the transmission HUD. Mesh-scope only — the host
// viewport gates by `canvas.scope == CanvasScope.mesh` before
// mounting this widget.
//
// Labels (lowercase, mesh-native):
//   - idle        — hidden entirely (zero footprint)
//   - recovering  — accent-tinted "recovering paint" + brush icon
//   - syncing     — accent-tinted "syncing tiles" + waves icon
//   - quiet       — tertiary "mesh quiet" + ear icon
//
// Anchored chrome: mounted as a sibling of CanvasViewer in the
// Stack so it never receives pan/zoom transforms.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../services/canvas/canvas_sync_coordinator.dart';
import '../providers/hydration_status_providers.dart';

class CanvasHydrationStatusHud extends ConsumerWidget {
  /// Mesh canvas to read hydration state for. The caller MUST ensure
  /// this is a mesh-scope canvas; local-scope mounts are gated
  /// upstream in the viewport body.
  final int canvasLocalId;

  const CanvasHydrationStatusHud({super.key, required this.canvasLocalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(
      meshCanvasHydrationStatusProvider(canvasLocalId),
    );
    final state = stateAsync.asData?.value;
    if (state == null || state == MeshCanvasHydrationState.idle) {
      return const SizedBox.shrink();
    }
    return Semantics(
      label: _tooltipFor(context, state),
      child: Tooltip(
        message: _tooltipFor(context, state),
        child: _HydrationPill(state: state),
      ),
    );
  }

  String _tooltipFor(BuildContext context, MeshCanvasHydrationState state) {
    final l = context.l10n;
    switch (state) {
      case MeshCanvasHydrationState.idle:
        return '';
      case MeshCanvasHydrationState.recovering:
        return l.meshCanvasHydrationTooltipRecovering;
      case MeshCanvasHydrationState.syncing:
        return l.meshCanvasHydrationTooltipSyncing;
      case MeshCanvasHydrationState.quiet:
        return l.meshCanvasHydrationTooltipQuiet;
    }
  }
}

class _HydrationPill extends StatelessWidget {
  final MeshCanvasHydrationState state;

  const _HydrationPill({required this.state});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final accent = context.accentColor;
    // recovering + syncing both use the accent tint — they're both
    // "the radio is carrying ink to us". quiet uses tertiary text
    // because it's "nothing heard yet", a calmer signal.
    final isAccent =
        state == MeshCanvasHydrationState.recovering ||
        state == MeshCanvasHydrationState.syncing;
    final tint = isAccent ? accent : context.textTertiary;
    final fill = tint.withValues(alpha: 0.12);
    final border = tint.withValues(alpha: 0.32);
    final label = switch (state) {
      MeshCanvasHydrationState.idle => '',
      MeshCanvasHydrationState.recovering => l.meshCanvasHydrationRecovering,
      MeshCanvasHydrationState.syncing => l.meshCanvasHydrationSyncing,
      MeshCanvasHydrationState.quiet => l.meshCanvasHydrationQuiet,
    };
    final iconData = switch (state) {
      MeshCanvasHydrationState.idle => Icons.brush_outlined,
      MeshCanvasHydrationState.recovering => Icons.download_outlined,
      MeshCanvasHydrationState.syncing => Icons.waves_outlined,
      MeshCanvasHydrationState.quiet => Icons.hearing_disabled_outlined,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: AppTheme.spacing6,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: border, width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 12, color: tint),
          const SizedBox(width: AppTheme.spacing6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tint,
              letterSpacing: 0.3,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
