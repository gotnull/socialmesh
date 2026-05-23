// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas transmission-status HUD pill.
//
// Spec anchor: docs/canvas/CANVAS_TRANSMISSION_STATUS_V0_1.md §3.1.
//
// A small anchored pill rendered at the top-right of the canvas frame
// (mirroring the presence strip at top-left). Mesh-scope only — the
// host viewport gates by `canvas.scope == CanvasScope.mesh` before
// mounting; this widget assumes that gate is already in place.
//
// Layout:
//   - hidden entirely when severity == idle (zero footprint on the
//     happy path);
//   - accent-tinted "N queued" pill when severity == queued;
//   - amber-tinted "cooling" pill when severity == cooling;
//   - amber-tinted "queue full · wait for airtime" pill with a
//     rotating wait indicator when severity == full.
//
// Anchored chrome: mounted OUTSIDE InteractiveViewer so it never
// receives the canvas pan / zoom transform. Regression-pinned in
// the widget tree test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../providers/transmission_status_providers.dart';
import '../../../services/canvas/canvas_transmission_status_models.dart';

class CanvasTransmissionStatusHud extends ConsumerWidget {
  /// Mesh canvas to read transmission status for. The caller MUST
  /// ensure this is a mesh-scope canvas; local-scope mounts are
  /// gated upstream in the viewport body.
  final int canvasLocalId;

  const CanvasTransmissionStatusHud({super.key, required this.canvasLocalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(
      meshCanvasTransmissionStatusProvider(canvasLocalId),
    );
    final status = statusAsync.asData?.value;
    // Idle (or still loading) → no chrome at all. Zero footprint on
    // the happy path matches the spec's "subtle, not punitive" tone.
    if (status == null ||
        status.severity == MeshCanvasTransmissionSeverity.idle) {
      return const SizedBox.shrink();
    }
    return Semantics(
      label: _tooltipFor(context, status),
      child: Tooltip(
        message: _tooltipFor(context, status),
        child: _StatusPill(status: status),
      ),
    );
  }

  String _tooltipFor(
    BuildContext context,
    MeshCanvasTransmissionStatus status,
  ) {
    final l = context.l10n;
    switch (status.severity) {
      case MeshCanvasTransmissionSeverity.idle:
        return '';
      case MeshCanvasTransmissionSeverity.queued:
        return l.meshCanvasTransmissionTooltipQueued(status.pendingCount);
      case MeshCanvasTransmissionSeverity.cooling:
        return l.meshCanvasTransmissionTooltipCooling;
      case MeshCanvasTransmissionSeverity.full:
        return l.meshCanvasTransmissionTooltipFull;
    }
  }
}

class _StatusPill extends StatelessWidget {
  final MeshCanvasTransmissionStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final accent = context.accentColor;
    // Amber for cooling / full — these are "ink waiting" states; the
    // colour cue is calm, not error-shaped. Queued uses the accent
    // because it is the normal in-flight state.
    final isWarning =
        status.severity == MeshCanvasTransmissionSeverity.cooling ||
        status.severity == MeshCanvasTransmissionSeverity.full;
    final tint = isWarning ? AppTheme.warningYellow : accent;
    final fill = tint.withValues(alpha: 0.12);
    final border = tint.withValues(alpha: 0.32);
    final label = switch (status.severity) {
      MeshCanvasTransmissionSeverity.idle => '',
      MeshCanvasTransmissionSeverity.queued => l.meshCanvasTransmissionQueued(
        status.pendingCount,
      ),
      MeshCanvasTransmissionSeverity.cooling => l.meshCanvasTransmissionCooling,
      MeshCanvasTransmissionSeverity.full => l.meshCanvasTransmissionFull,
    };
    final iconData = switch (status.severity) {
      MeshCanvasTransmissionSeverity.idle => Icons.brush_outlined,
      MeshCanvasTransmissionSeverity.queued => Icons.brush_outlined,
      MeshCanvasTransmissionSeverity.cooling => Icons.hourglass_bottom,
      MeshCanvasTransmissionSeverity.full => Icons.pause_circle_outline,
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
