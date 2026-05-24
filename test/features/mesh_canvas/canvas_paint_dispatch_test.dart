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
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/features/mesh_canvas/providers/mesh_canvas_participation_providers.dart';
import 'package:socialmesh/features/mesh_canvas/providers/mesh_canvas_providers.dart';
import 'package:socialmesh/features/mesh_canvas/providers/transmission_status_providers.dart';
import 'package:socialmesh/services/canvas/canvas_transmission_status_models.dart';
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

const _meshCanvas = CanvasSummary(
  localId: 2,
  canvasId: 0x12345678ABCDEF01,
  scope: CanvasScope.mesh,
  channelIndex: 3,
  name: 'Primary',
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

Future<_RecordingCanvasRepository> _pumpViewer(
  WidgetTester tester, {
  required CanvasSummary canvas,
  int? myNodeNum = 0x0864,
  bool participationEnabled = true,
  MeshCanvasTransmissionStatus? transmissionStatus,
}) async {
  // Seed the participation prefs BEFORE the provider container resolves
  // its AsyncNotifier. Default `true` so existing dispatch tests stay
  // green; the gate test below passes `false` explicitly.
  SharedPreferences.setMockInitialValues({
    'mesh_canvas.participation.onboarding_seen': true,
    'mesh_canvas.participation.enabled': participationEnabled,
    'mesh_canvas.participation.presence_sharing_enabled': false,
  });
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
      // Force a transmission-status state when the test cares about
      // the queue gate; otherwise let the real provider chain emit
      // (which defaults to idle on a fresh DB).
      if (transmissionStatus != null)
        meshCanvasTransmissionStatusProvider(canvas.localId).overrideWith(
          (ref) =>
              Stream<MeshCanvasTransmissionStatus>.value(transmissionStatus),
        ),
    ],
  );
  addTearDown(container.dispose);
  // Pre-warm the async repo + participation provider so the viewer's
  // synchronous `ref.read(...)` reads return the seeded values.
  await container.read(canvasRepositoryProvider.future);
  await container.read(meshCanvasParticipationProvider.future);

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

    // S4 participation gate — defence in depth. The Mesh tab in the
    // overview hides the channel list while participation is off, but
    // a deep-link / programmatic push could otherwise surface this
    // viewer. The paint handler MUST silently skip the enqueue.
    // Spec: docs/canvas/CANVAS_PARTICIPATION_V0_1.md §5.3 + §8 I4.
    testWidgets(
      'Mesh Canvas tap with participation disabled is silently blocked — '
      'no enqueue happens even if the viewer is somehow surfaced',
      (tester) async {
        final repo = await _pumpViewer(
          tester,
          canvas: _meshCanvas,
          participationEnabled: false,
        );

        await tester.tap(find.byType(MeshCanvasViewerScreen));
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          repo.calls,
          isEmpty,
          reason: 'participation gate must block mesh paint enqueue',
        );
      },
    );

    // I2 Local Canvas immunity — Local paint MUST work even when
    // participation is off. The Local sandbox is private + offline
    // and must remain available regardless of participation settings.
    testWidgets(
      'Local Device Canvas tap with participation disabled still works — '
      'Local sandbox is independent of participation settings (I2)',
      (tester) async {
        final repo = await _pumpViewer(
          tester,
          canvas: _localCanvas,
          participationEnabled: false,
        );

        await tester.tap(find.byType(MeshCanvasViewerScreen));
        await tester.pump(const Duration(milliseconds: 200));

        expect(repo.calls, hasLength(1));
        expect(repo.calls.single.method, 'paintLocal');
      },
    );

    // Tap-layer scarcity: when the mesh transmission HUD is at
    // severity=full (pending queue >= softQueueCap), the paint
    // handler MUST silently reject the tap. No `enqueuePaint` call,
    // no local cell mutation. The HUD pill is the user-facing
    // explanation; the periodic drain timer in the lifecycle host
    // is the deadlock backstop. Spec: anti-spam brief item 2
    // ("Queue-aware paint blocking").
    testWidgets(
      'Mesh Canvas tap with transmission severity=full is silently rejected — '
      'no enqueue, no cell mutation; HUD pill explains why',
      (tester) async {
        final repo = await _pumpViewer(
          tester,
          canvas: _meshCanvas,
          transmissionStatus: const MeshCanvasTransmissionStatus(
            pendingCount: 32,
            oldestPendingAtMs: 1_000,
            nextAttemptAtMs: 1_500,
            isCanvasBudgetCooling: false,
            isSipBudgetCooling: false,
            canPaint: false,
            severity: MeshCanvasTransmissionSeverity.full,
          ),
        );

        await tester.tap(find.byType(MeshCanvasViewerScreen));
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          repo.calls,
          isEmpty,
          reason:
              'severity=full must block fresh mesh paint taps; the '
              'queue gate is the user-visible scarcity mechanism.',
        );
      },
    );

    // Local Canvas paths remain unaffected by mesh transmission
    // state (I2 — Local Canvas immunity). Confirms the local code
    // path never even reads the transmission selector.
    testWidgets(
      'Local Canvas paint with severity=full transmission state still works '
      '— Local sandbox is independent of mesh transmission state',
      (tester) async {
        final repo = await _pumpViewer(
          tester,
          canvas: _localCanvas,
          transmissionStatus: const MeshCanvasTransmissionStatus(
            pendingCount: 32,
            oldestPendingAtMs: 1_000,
            nextAttemptAtMs: 1_500,
            isCanvasBudgetCooling: false,
            isSipBudgetCooling: false,
            canPaint: false,
            severity: MeshCanvasTransmissionSeverity.full,
          ),
        );

        await tester.tap(find.byType(MeshCanvasViewerScreen));
        await tester.pump(const Duration(milliseconds: 200));

        expect(repo.calls, hasLength(1));
        expect(repo.calls.single.method, 'paintLocal');
      },
    );
  });
}
