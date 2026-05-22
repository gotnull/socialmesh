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
    initialChildSize: 0.7,
    minChildSize: 0.4,
    maxChildSize: 0.95,
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
    extends ConsumerState<_CanvasTileInspectorSheet> {
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
    final l = context.l10n;
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
          l: l,
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
  // ignore: library_private_types_in_public_api
  final dynamic l;

  const _InspectorBody({
    required this.scrollController,
    required this.canvas,
    required this.x,
    required this.y,
    required this.data,
    required this.l,
  });

  String _authorLabel(int authorNodeNum) {
    if (canvas.scope == CanvasScope.local) {
      return l.meshCanvasInspectorAuthorLocal as String;
    }
    final hex = authorNodeNum.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    return l.meshCanvasInspectorAuthorNode(hex) as String;
  }

  String _relative(int unixSeconds) {
    final ts = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
    final delta = DateTime.now().difference(ts);
    if (delta.inMinutes < 1) return l.nodedexRelativeJustNow as String;
    if (delta.inMinutes < 60) {
      return l.nodedexRelativeMinutesAgo(delta.inMinutes) as String;
    }
    if (delta.inHours < 24) {
      return l.nodedexRelativeHoursAgo(delta.inHours) as String;
    }
    if (delta.inDays < 30) {
      return l.nodedexRelativeDaysAgo(delta.inDays) as String;
    }
    return l.nodedexRelativeMonthsAgo(delta.inDays ~/ 30) as String;
  }

  @override
  Widget build(BuildContext context) {
    final cell = data.cell;
    final history = data.history;

    final currentColorValue = cell == null
        ? l.meshCanvasInspectorEmptyCellLabel as String
        : SocialMeshPalette.nameOf(cell.color);

    final rows = <InfoTableRow>[
      InfoTableRow(
        icon: Icons.palette_outlined,
        label: l.meshCanvasInspectorCurrentColorLabel as String,
        value: currentColorValue,
      ),
      if (cell != null) ...[
        InfoTableRow(
          icon: Icons.person_outline,
          label: l.meshCanvasInspectorLastPainterLabel as String,
          value: _authorLabel(cell.lastAuthor),
        ),
        InfoTableRow(
          icon: Icons.schedule_outlined,
          label: l.meshCanvasInspectorLastPaintedLabel as String,
          value: _relative(cell.lastTs),
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
          title: (l.meshCanvasInspectorTitle(x, y) as String),
          leadingIcon: Icons.center_focus_strong_outlined,
        ),
        InfoTable(rows: rows),
        const SizedBox(height: AppTheme.spacing16),
        SectionTitle(
          title: l.meshCanvasInspectorHistoryHeading as String,
          leadingIcon: Icons.history,
        ),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing4,
              vertical: AppTheme.spacing8,
            ),
            child: Text(
              l.meshCanvasInspectorHistoryEmpty as String,
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
                    label: _authorLabel(op.authorNodeNum),
                    value:
                        '${SocialMeshPalette.nameOf(op.color)} · ${_relative(op.opTs)}',
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
