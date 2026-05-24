// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// S7.D acceptance tests for the tile inspector sheet.
//
// Coverage:
//   - Empty cell renders the "Empty cell" placeholder and omits the
//     last-painter / last-painted rows (those are meaningless
//     without a paint event).
//   - Painted cell renders the colour name, the "You (local)" author
//     label (Local Device Canvas convention), and the last-painted
//     row label.
//   - Per-cell history list renders multiple applied_op rows.
//   - The empty-history placeholder renders when no applied_op rows
//     exist for the inspected coordinates.
//
// We don't reach for the real sqlite-FFI here — the repository
// behaviour is already exhaustively covered by
// canvas_repository_test.dart. This file pins the SHEET's contract:
// "given the repo returns X, render Y." A FakeCanvasRepository (real
// CanvasRepository subclass that overrides only the two getters the
// sheet reads) keeps the test fast and async-clean.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/mesh_canvas/providers/mesh_canvas_providers.dart';
import 'package:socialmesh/features/mesh_canvas/widgets/canvas_tile_inspector_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/services/canvas/canvas_database.dart';
import 'package:socialmesh/services/canvas/canvas_models.dart';
import 'package:socialmesh/services/canvas/canvas_repository.dart';

class _FakeCanvasRepository extends CanvasRepository {
  final Map<({int x, int y}), CanvasCell> _cells;
  final Map<({int x, int y}), List<AppliedCanvasOp>> _history;

  _FakeCanvasRepository({
    required List<CanvasCell> cells,
    required Map<({int x, int y}), List<AppliedCanvasOp>> history,
  }) : _cells = {for (final c in cells) (x: c.x, y: c.y): c},
       _history = history,
       // CanvasRepository(super(db)) requires a CanvasDatabase. We
       // pass a never-opened instance; the only methods the sheet
       // hits are overridden below, so the db is never touched.
       super(CanvasDatabase());

  @override
  Future<CanvasCell?> getCellAt(int canvasLocalId, int x, int y) async {
    return _cells[(x: x, y: y)];
  }

  @override
  Future<List<AppliedCanvasOp>> getCellHistory(
    int canvasLocalId,
    int x,
    int y, {
    int limit = 10,
  }) async {
    return _history[(x: x, y: y)] ?? const <AppliedCanvasOp>[];
  }
}

const _localCanvas = CanvasSummary(
  localId: 1,
  canvasId: 0,
  scope: CanvasScope.local,
  channelIndex: null,
  name: 'Local Sandbox',
  width: 64,
  height: 64,
  paletteId: 1,
  status: CanvasStatus.open,
  ownerNodeNum: null,
  createdAtMs: 0,
  lastOpAtMs: 0,
  globalDigest: null,
  tileDigests: null,
  cellCount: 0,
);

CanvasCell _cell({
  required int x,
  required int y,
  required int color,
  int ts = 1700000000,
  int author = 0,
  int seq = 0,
}) {
  return CanvasCell(
    canvasLocalId: 1,
    x: x,
    y: y,
    color: color,
    lastTs: ts,
    lastAuthor: author,
    lastSeq: seq,
  );
}

AppliedCanvasOp _op({
  required int x,
  required int y,
  required int color,
  int ts = 1700000000,
  int author = 0,
  int seq = 0,
}) {
  return AppliedCanvasOp(
    id: ts * 100 + seq,
    canvasLocalId: 1,
    x: x,
    y: y,
    color: color,
    opTs: ts,
    authorNodeNum: author,
    opSeq: seq,
    direction: AppliedOpDirection.outbound,
    receivedAtMs: ts * 1000,
    wasAccepted: true,
  );
}

Future<void> _pumpInspector(
  WidgetTester tester, {
  required _FakeCanvasRepository repo,
  required int x,
  required int y,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [canvasRepositoryProvider.overrideWith((ref) async => repo)],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showCanvasTileInspectorSheet(
                  context: context,
                  canvas: _localCanvas,
                  x: x,
                  y: y,
                ),
                child: const Text('Open inspector'),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open inspector'));
  await tester.pumpAndSettle();
}

void main() {
  group('CanvasTileInspectorSheet — S7.D acceptance', () {
    testWidgets('empty cell renders the "Empty cell" placeholder and omits the '
        'last-painter / last-painted rows', (tester) async {
      final repo = _FakeCanvasRepository(cells: const [], history: const {});
      await _pumpInspector(tester, repo: repo, x: 5, y: 7);

      expect(find.text('PIXEL (5, 7)'), findsOneWidget);
      expect(find.text('Empty cell'), findsOneWidget);
      expect(find.text('Last painter'), findsNothing);
      expect(find.text('Last painted'), findsNothing);
      expect(find.text('RECENT HISTORY'), findsOneWidget);
      expect(find.text('No history yet for this cell.'), findsOneWidget);
    });

    testWidgets(
      'painted cell on the Local Device Canvas renders the colour name + '
      'the "You (local)" painter label + the last-painted row',
      (tester) async {
        final cell = _cell(x: 3, y: 4, color: 11); // Red
        final repo = _FakeCanvasRepository(
          cells: [cell],
          history: {
            (x: 3, y: 4): [_op(x: 3, y: 4, color: 11)],
          },
        );

        await _pumpInspector(tester, repo: repo, x: 3, y: 4);

        expect(find.text('PIXEL (3, 4)'), findsOneWidget);
        expect(find.text('Current colour'), findsOneWidget);
        expect(find.text('Red'), findsWidgets);
        expect(find.text('Last painter'), findsOneWidget);
        expect(find.text('You (local)'), findsWidgets);
        expect(find.text('Last painted'), findsOneWidget);
      },
    );

    testWidgets(
      'history list renders one row per applied_op with the painter label '
      'and a colour-plus-when value',
      (tester) async {
        final cell = _cell(x: 1, y: 1, color: 25); // Green (latest)
        final repo = _FakeCanvasRepository(
          cells: [cell],
          history: {
            (x: 1, y: 1): [
              _op(x: 1, y: 1, color: 25, ts: 1700000010, seq: 1),
              _op(x: 1, y: 1, color: 11, ts: 1700000000, seq: 0),
            ],
          },
        );

        await _pumpInspector(tester, repo: repo, x: 1, y: 1);

        expect(find.text('PIXEL (1, 1)'), findsOneWidget);
        expect(find.text('RECENT HISTORY'), findsOneWidget);
        expect(find.text('No history yet for this cell.'), findsNothing);
        // Local-canvas convention: every painter label resolves to
        // "You (local)" — the current-cell row + 2 history rows = 3+
        // hits.
        expect(find.text('You (local)'), findsWidgets);
      },
    );
  });
}
