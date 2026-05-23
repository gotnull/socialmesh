// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Painter-level tests for the pending-pixel opacity treatment.
//
// Spec: docs/canvas/CANVAS_TRANSMISSION_STATUS_V0_1.md §3.2.
//
// Strategy: stub the Canvas, capture `drawRect` calls + the active
// paint color, and assert that cells whose packed coordinate is in
// `pendingCellIndices` paint at `color.a * pendingOpacityFactor`
// while non-pending cells paint at the full palette alpha.

import 'dart:ui';

import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/mesh_canvas/widgets/canvas_grid_painter.dart';
import 'package:socialmesh/services/canvas/canvas_models.dart';

class _RecordedDraw {
  final Rect rect;
  final double alpha;
  final Color color;
  const _RecordedDraw({
    required this.rect,
    required this.alpha,
    required this.color,
  });
}

class _RecordingCanvas implements Canvas {
  final List<_RecordedDraw> draws = <_RecordedDraw>[];

  @override
  void drawRect(Rect rect, Paint paint) {
    // Skip large surface / outside-fill rects so we only capture the
    // per-cell draws.
    if (rect.width > 100 || rect.height > 100) return;
    draws.add(
      _RecordedDraw(rect: rect, alpha: paint.color.a, color: paint.color),
    );
  }

  // Stub every other Canvas method to a no-op. The painter only uses
  // drawRect + drawLine; drawLine is also a no-op for our purposes.
  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {}

  @override
  void noSuchMethod(Invocation invocation) {}
}

void main() {
  const cellSize = 4.0;
  const surface = Color(0xFF161A22);
  const outside = Color(0xFF0B0D11);
  const chunk = Color(0x14FFFFFF);
  const ring = Color(0x66FFFFFF);
  final palette = <Color>[
    const Color(0x00000000), // transparent sentinel
    Colors.red,
    Colors.green,
    Colors.blue,
  ];

  test(
    'pending cells render at color.a × pendingOpacityFactor; non-pending at full alpha',
    () {
      final cells = <CanvasCell>[
        const CanvasCell(
          canvasLocalId: 1,
          x: 1,
          y: 2,
          color: 1, // red
          lastTs: 0,
          lastAuthor: 0,
          lastSeq: 0,
        ),
        const CanvasCell(
          canvasLocalId: 1,
          x: 3,
          y: 4,
          color: 2, // green
          lastTs: 0,
          lastAuthor: 0,
          lastSeq: 0,
        ),
      ];
      // Mark only (1, 2) as pending.
      final pending = <int>{2 * 128 + 1};

      final painter = CanvasGridPainter(
        cells: cells,
        palette: palette,
        cellSize: cellSize,
        outsideColor: outside,
        surfaceColor: surface,
        chunkLineColor: chunk,
        borderColor: ring,
        pendingCellIndices: pending,
      );

      final recording = _RecordingCanvas();
      painter.paint(recording, const Size(128 * cellSize, 128 * cellSize));

      final drawsByCell = {for (final d in recording.draws) d.rect.topLeft: d};
      // (1, 2) cell → pending → reduced alpha.
      final pendingDraw = drawsByCell[const Offset(cellSize, 2 * cellSize)];
      expect(pendingDraw, isNotNull);
      expect(
        pendingDraw!.alpha,
        closeTo(1.0 * 0.55, 0.001),
        reason: 'pending cell alpha must be palette alpha * 0.55',
      );
      // (3, 4) cell → not pending → full alpha.
      final fullDraw = drawsByCell[const Offset(3 * cellSize, 4 * cellSize)];
      expect(fullDraw, isNotNull);
      expect(fullDraw!.alpha, closeTo(1.0, 0.001));
    },
  );

  test('empty pendingCellIndices set leaves every cell at full alpha', () {
    final cells = <CanvasCell>[
      const CanvasCell(
        canvasLocalId: 1,
        x: 0,
        y: 0,
        color: 1,
        lastTs: 0,
        lastAuthor: 0,
        lastSeq: 0,
      ),
    ];

    final painter = CanvasGridPainter(
      cells: cells,
      palette: palette,
      cellSize: cellSize,
      outsideColor: outside,
      surfaceColor: surface,
      chunkLineColor: chunk,
      borderColor: ring,
      // No pending set — explicit default.
    );

    final recording = _RecordingCanvas();
    painter.paint(recording, const Size(128 * cellSize, 128 * cellSize));

    final cellDraws = recording.draws
        .where((d) => d.rect.size == const Size(cellSize, cellSize))
        .toList();
    expect(cellDraws, hasLength(1));
    expect(cellDraws.single.alpha, closeTo(1.0, 0.001));
  });

  test('shouldRepaint flips when pendingCellIndices reference changes', () {
    final cells = <CanvasCell>[
      const CanvasCell(
        canvasLocalId: 1,
        x: 0,
        y: 0,
        color: 1,
        lastTs: 0,
        lastAuthor: 0,
        lastSeq: 0,
      ),
    ];
    final pendingA = <int>{1};
    final pendingB = <int>{1}; // identical contents, different identity

    final a = CanvasGridPainter(
      cells: cells,
      palette: palette,
      cellSize: cellSize,
      outsideColor: outside,
      surfaceColor: surface,
      chunkLineColor: chunk,
      borderColor: ring,
      pendingCellIndices: pendingA,
    );
    final b = CanvasGridPainter(
      cells: cells,
      palette: palette,
      cellSize: cellSize,
      outsideColor: outside,
      surfaceColor: surface,
      chunkLineColor: chunk,
      borderColor: ring,
      pendingCellIndices: pendingB,
    );
    expect(
      b.shouldRepaint(a),
      isTrue,
      reason:
          'identity-based repaint trigger fires when the pending set is '
          'rebuilt (fresh reference)',
    );
  });
}
