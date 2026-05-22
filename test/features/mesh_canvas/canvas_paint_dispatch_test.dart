// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// S8 paint-dispatch acceptance tests for the MeshCanvas viewer.
//
// What this file pins:
//   1) Local canvas taps go through CanvasRepository.paintLocal —
//      never enqueuePaint. Local Device Canvas paints MUST NOT
//      leak into the outbound queue (per spec §S0.rate.7: relaxed
//      / never broadcast).
//   2) Mesh canvas taps go through CanvasRepository.enqueuePaint —
//      never paintLocal. The real author_node_num is wired through
//      from myNodeNumProvider so receivers can run LWW correctly.
//   3) If myNodeNumProvider returns null on a mesh canvas (link not
//      connected), the paint is silently skipped — no broken op in
//      pending_op, no rejected wire frame.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/mesh_canvas/providers/mesh_canvas_providers.dart';
import 'package:socialmesh/features/mesh_canvas/screens/mesh_canvas_viewer_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/canvas/canvas_database.dart';
import 'package:socialmesh/services/canvas/canvas_models.dart';
import 'package:socialmesh/services/canvas/canvas_repository.dart';

class _RecordingCanvasRepository extends CanvasRepository {
  final List<
    ({String method, int canvasLocalId, int x, int y, int color, int author})
  >
  calls = [];

  _RecordingCanvasRepository() : super(CanvasDatabase());

  @override
  Future<bool> paintLocal({
    required int canvasLocalId,
    required int x,
    required int y,
    required int color,
    required int authorNodeNum,
    required int opTs,
    required int opSeq,
    int? receivedAtMsOverride,
  }) async {
    calls.add((
      method: 'paintLocal',
      canvasLocalId: canvasLocalId,
      x: x,
      y: y,
      color: color,
      author: authorNodeNum,
    ));
    return true;
  }

  @override
  Future<bool> enqueuePaint({
    required int canvasLocalId,
    required int x,
    required int y,
    required int color,
    required int authorNodeNum,
    required int opTs,
    required int opSeq,
    int? receivedAtMsOverride,
    int? createdAtMsOverride,
  }) async {
    calls.add((
      method: 'enqueuePaint',
      canvasLocalId: canvasLocalId,
      x: x,
      y: y,
      color: color,
      author: authorNodeNum,
    ));
    return true;
  }

  @override
  Future<List<CanvasCell>> getCanvasCells(int canvasLocalId) async =>
      const <CanvasCell>[];

  // The mesh-canvas branch fires a CanvasSendCoordinator.drain() after
  // enqueueing. The coordinator immediately calls getQueuedReadyOps —
  // override to short-circuit so the drain finds nothing and exits
  // without touching the never-initialised fake CanvasDatabase the
  // super constructor required.
  @override
  Future<List<PendingCanvasOp>> getQueuedReadyOps({
    required int nowMs,
    int limit = 32,
  }) async => const <PendingCanvasOp>[];
}

const _localCanvas = CanvasSummary(
  localId: 1,
  canvasId: 0,
  scope: CanvasScope.local,
  channelIndex: null,
  name: 'Local Sandbox',
  width: 128,
  height: 128,
  paletteId: 1,
  status: CanvasStatus.open,
  ownerNodeNum: null,
  createdAtMs: 0,
  lastOpAtMs: 0,
  globalDigest: null,
  tileDigests: null,
  cellCount: 0,
);

const _meshCanvas = CanvasSummary(
  localId: 2,
  canvasId: 0x12345678ABCDEF01,
  scope: CanvasScope.mesh,
  channelIndex: 3,
  name: 'Primary',
  width: 128,
  height: 128,
  paletteId: 1,
  status: CanvasStatus.open,
  ownerNodeNum: null,
  createdAtMs: 0,
  lastOpAtMs: 0,
  globalDigest: null,
  tileDigests: null,
  cellCount: 0,
);

Future<_RecordingCanvasRepository> _pumpViewer(
  WidgetTester tester, {
  required CanvasSummary canvas,
  int? myNodeNum = 0x0864,
}) async {
  final repo = _RecordingCanvasRepository();
  final container = ProviderContainer(
    overrides: [
      canvasRepositoryProvider.overrideWith((ref) async => repo),
      canvasCellsProvider(
        canvas.localId,
      ).overrideWith((ref) async => const <CanvasCell>[]),
      myNodeNumProvider.overrideWith(
        () => _StubMyNodeNumNotifier(initial: myNodeNum),
      ),
    ],
  );
  addTearDown(container.dispose);
  // Pre-warm the async repo so the viewer's `ref.read(...).asData?.value`
  // synchronous read returns the fake instead of skipping on "repository
  // not ready" — in production the overview screen has already
  // materialised the chain before the viewer pushes.
  await container.read(canvasRepositoryProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: MeshCanvasViewerScreen(canvas: canvas),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

class _StubMyNodeNumNotifier extends MyNodeNumNotifier {
  final int? initial;

  _StubMyNodeNumNotifier({required this.initial});

  @override
  int? build() => initial;
}

void main() {
  group('viewer paint dispatch — S8 acceptance', () {
    testWidgets(
      'Local Device Canvas tap goes through paintLocal, never enqueuePaint',
      (tester) async {
        final repo = await _pumpViewer(tester, canvas: _localCanvas);

        // Tap the centre of the viewer.
        await tester.tap(find.byType(MeshCanvasViewerScreen));
        await tester.pump(const Duration(milliseconds: 200));

        expect(repo.calls.length, 1);
        expect(repo.calls.single.method, 'paintLocal');
        // Local canvases use a constant author=0 (informational).
        expect(repo.calls.single.author, 0);
      },
    );

    testWidgets('Mesh Canvas tap goes through enqueuePaint with the real local '
        'node_num as author', (tester) async {
      final repo = await _pumpViewer(
        tester,
        canvas: _meshCanvas,
        myNodeNum: 0x0864,
      );

      await tester.tap(find.byType(MeshCanvasViewerScreen));
      await tester.pump(const Duration(milliseconds: 200));

      expect(repo.calls.length, 1);
      expect(repo.calls.single.method, 'enqueuePaint');
      expect(repo.calls.single.author, 0x0864);
    });

    testWidgets(
      'Mesh Canvas tap with unknown myNodeNum (link not connected) is '
      'silently skipped — no enqueue happens',
      (tester) async {
        final repo = await _pumpViewer(
          tester,
          canvas: _meshCanvas,
          myNodeNum: null,
        );

        await tester.tap(find.byType(MeshCanvasViewerScreen));
        await tester.pump(const Duration(milliseconds: 200));

        expect(repo.calls, isEmpty);
      },
    );
  });
}
