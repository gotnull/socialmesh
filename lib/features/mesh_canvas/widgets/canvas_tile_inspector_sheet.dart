// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// S7.D tile inspector sheet for the MeshCanvas viewer.
//
// Spec anchor: docs/canvas/CANVAS_V0_1.md §S0.ux.15 — "long-press
// opens the tile inspector (last painter / paint time / per-cell
// op history)."
//
// What the sheet shows for one cell:
//   - Current colour (palette name + filled swatch); the empty-cell
//     branch renders "Empty cell" when nothing has ever landed here.
//   - Last painter — "You (local)" on the Local Device Canvas (every
//     paint is the local user), or "Node !<hex8>" on mesh canvases.
//   - Last painted — relative time via the canonical
//     nodedexRelativeXxx ARB keys.
//   - Recent history — up to 10 most-recent applied_op entries for
//     this exact cell, newest first. Empty placeholder when fresh.
//
// Async path: the sheet opens immediately and renders a tiny spinner
// while CanvasRepository.getCellAt + getCellHistory resolve. Both
// reads hit indexed paths (cell pk and idx_applied_canvas_cell), so
// the spinner usually flashes for a single frame.
//
// Mandatory primitives: SectionTitle for the heading row, InfoTable
// + InfoTableRow for the value rows. Hand-rolled Row(label+value)
// layouts are explicitly banned in this codebase.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/canvas/canvas_palette.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../../../services/canvas/canvas_models.dart';
import '../providers/mesh_canvas_providers.dart';

/// Open the tile inspector for a single cell on a canvas.
///
/// [canvas] determines the data source (Local Device Canvas uses a
/// "You (local)" painter label since author=0 is always the local
/// user; mesh canvases render the node-num hex). [x] and [y] are in
/// canvas-cell space (0..widthCells-1).
Future<void> showCanvasTileInspectorSheet({
  required BuildContext context,
  required CanvasSummary canvas,
  required int x,
  required int y,
}) {
  return AppBottomSheet.showScrollable<void>(
    context: context,
    // Sized for the typical case: 3 info rows + 1-3 history rows.
    // The maxChildSize stays high so a busy cell with a long history
    // can drag-expand without re-rendering. Was 0.7 / 0.4 / 0.95;
    // 70% initial left ~half the sheet empty for the common case.
    initialChildSize: 0.45,
    minChildSize: 0.3,
    maxChildSize: 0.9,
    builder: (controller) => _CanvasTileInspectorSheet(
      scrollController: controller,
      canvas: canvas,
      x: x,
      y: y,
    ),
  );
}

class _CanvasTileInspectorSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final CanvasSummary canvas;
  final int x;
  final int y;

  const _CanvasTileInspectorSheet({
    required this.scrollController,
    required this.canvas,
    required this.x,
    required this.y,
  });

  @override
  ConsumerState<_CanvasTileInspectorSheet> createState() =>
      _CanvasTileInspectorSheetState();
}

class _CanvasTileInspectorSheetState
    extends ConsumerState<_CanvasTileInspectorSheet>
    with LifecycleSafeMixin<_CanvasTileInspectorSheet> {
  Future<_InspectorData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_InspectorData> _load() async {
    final repo = await ref.read(canvasRepositoryProvider.future);
    final cell = await repo.getCellAt(
      widget.canvas.localId,
      widget.x,
      widget.y,
    );
    final history = await repo.getCellHistory(
      widget.canvas.localId,
      widget.x,
      widget.y,
    );
    return _InspectorData(cell: cell, history: history);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_InspectorData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spacing24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        return _InspectorBody(
          scrollController: widget.scrollController,
          canvas: widget.canvas,
          x: widget.x,
          y: widget.y,
          data: snapshot.data!,
        );
      },
    );
  }
}

class _InspectorBody extends StatelessWidget {
  final ScrollController scrollController;
  final CanvasSummary canvas;
  final int x;
  final int y;
  final _InspectorData data;

  const _InspectorBody({
    required this.scrollController,
    required this.canvas,
    required this.x,
    required this.y,
    required this.data,
  });

  String _authorLabel(BuildContext context, int authorNodeNum) {
    final l = context.l10n;
    if (canvas.scope == CanvasScope.local) {
      return l.meshCanvasInspectorAuthorLocal;
    }
    final hex = authorNodeNum.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    return l.meshCanvasInspectorAuthorNode(hex);
  }

  String _relative(BuildContext context, int unixSeconds) {
    final l = context.l10n;
    final ts = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
    final delta = DateTime.now().difference(ts);
    if (delta.inMinutes < 1) return l.nodedexRelativeJustNow;
    if (delta.inMinutes < 60) {
      return l.nodedexRelativeMinutesAgo(delta.inMinutes);
    }
    if (delta.inHours < 24) {
      return l.nodedexRelativeHoursAgo(delta.inHours);
    }
    if (delta.inDays < 30) {
      return l.nodedexRelativeDaysAgo(delta.inDays);
    }
    return l.nodedexRelativeMonthsAgo(delta.inDays ~/ 30);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cell = data.cell;
    final history = data.history;

    final currentColorValue = cell == null
        ? l.meshCanvasInspectorEmptyCellLabel
        : SocialMeshPalette.nameOf(cell.color);

    final rows = <InfoTableRow>[
      InfoTableRow(
        icon: Icons.palette_outlined,
        label: l.meshCanvasInspectorCurrentColorLabel,
        value: currentColorValue,
      ),
      if (cell != null) ...[
        InfoTableRow(
          icon: Icons.person_outline,
          label: l.meshCanvasInspectorLastPainterLabel,
          value: _authorLabel(context, cell.lastAuthor),
        ),
        InfoTableRow(
          icon: Icons.schedule_outlined,
          label: l.meshCanvasInspectorLastPaintedLabel,
          value: _relative(context, cell.lastTs),
        ),
      ],
    ];

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing24,
      ),
      children: [
        SectionTitle(
          title: l.meshCanvasInspectorTitle(x, y),
          leadingIcon: Icons.center_focus_strong_outlined,
        ),
        InfoTable(rows: rows),
        const SizedBox(height: AppTheme.spacing16),
        SectionTitle(
          title: l.meshCanvasInspectorHistoryHeading,
          leadingIcon: Icons.history,
        ),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing4,
              vertical: AppTheme.spacing8,
            ),
            child: Text(
              l.meshCanvasInspectorHistoryEmpty,
              style: TextStyle(
                fontSize: 13,
                color: context.textTertiary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          )
        else
          InfoTable(
            rows: history
                .map(
                  (op) => InfoTableRow(
                    icon: Icons.brush_outlined,
                    label: _authorLabel(context, op.authorNodeNum),
                    value:
                        '${SocialMeshPalette.nameOf(op.color)} · ${_relative(context, op.opTs)}',
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _InspectorData {
  final CanvasCell? cell;
  final List<AppliedCanvasOp> history;

  const _InspectorData({required this.cell, required this.history});
}
