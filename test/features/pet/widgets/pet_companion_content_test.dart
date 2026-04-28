// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Widget tests for the NodeDex detail integration point.
//
// Covers:
//   * empty state (no observation) renders the "unknown" text
//   * observation + active band renders the band pip with label
//   * observation + unknown band renders NO band line (by design —
//     "unknown" is internal-only, never a user-facing label)
//   * observation + sleepy band renders its label
//
// We override:
//   * peerPetObservationProvider(nodeNum) — sync-derived observation
//   * peerLastSeenProvider(nodeNum) — presence freshness
//   * petRemoteClientProvider — null (suppress the broadcast fetch)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/care_accumulators.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/models/pet_public_state.dart';
import 'package:socialmesh/features/pet/models/pet_state.dart';
import 'package:socialmesh/features/pet/models/remote_pet_share_status.dart';
import 'package:socialmesh/features/pet/providers/pet_providers.dart';
import 'package:socialmesh/features/pet/services/pet_repository.dart';
import 'package:socialmesh/features/pet/widgets/pet_companion_card.dart';
import 'package:socialmesh/features/pet/widgets/pet_mini_preview.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/app_providers.dart';

PetPublicState _pub({
  PetStage stage = PetStage.adult,
  PetBranch branch = PetBranch.steady,
  PetMood mood = PetMood.content,
  bool isAsleep = false,
  int ageInDays = 10,
}) => PetPublicState(
  dnaSeed: 0xdeadbeef,
  stage: stage,
  branch: branch,
  mood: mood,
  ageInDays: ageInDays,
  isAsleep: isAsleep,
  isSick: false,
  isCalling: false,
  isEvolving: false,
);

Widget _harness({
  required int nodeNum,
  required RemotePetObservation? observation,
  required DateTime? lastSeen,
}) {
  return ProviderScope(
    overrides: [
      // The widget reads the FutureProvider directly for the preview.
      remotePetProvider(nodeNum).overrideWith((ref) async => observation),
      // The Notifier reads the sync-derived observation for live-state.
      peerPetObservationProvider(nodeNum).overrideWith((ref) => observation),
      peerLastSeenProvider(nodeNum).overrideWith((ref) => lastSeen),
      petRemoteClientProvider.overrideWith((ref) => null),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PetCompanionContent(nodeNum: nodeNum)),
    ),
  );
}

void main() {
  testWidgets(
    'no observation + unknown share status → "no companion seen yet" copy',
    (tester) async {
      await tester.pumpWidget(
        _harness(nodeNum: 101, observation: null, lastSeen: null),
      );
      // pumpAndSettle() hangs because PetCreature's animation ticker
      // never stops — pump a few discrete frames instead so the
      // FutureProvider override resolves and the widget paints once.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.byType(PetPreviewFromState), findsNothing);
      expect(
        find.text('No companion seen from this node yet.'),
        findsOneWidget,
      );
      // The "not sharing" copy belongs to a different code path.
      expect(find.text("This node isn't sharing its companion."), findsNothing);
    },
  );

  testWidgets(
    'no observation + notSharing share status → "this node isn\'t sharing" copy',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remotePetProvider(110).overrideWith((ref) async => null),
            peerPetObservationProvider(110).overrideWith((ref) => null),
            peerLastSeenProvider(110).overrideWith((ref) => null),
            petRemoteClientProvider.overrideWith((ref) => null),
            remotePetShareStatusProvider(110).overrideWith(
              () => _FakeShareStatus(RemotePetShareStatus.notSharing),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: PetCompanionContent(nodeNum: 110)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.byType(PetPreviewFromState), findsNothing);
      expect(
        find.text("This node isn't sharing its companion."),
        findsOneWidget,
      );
      // The generic no-observation copy must not leak into this state.
      expect(find.text('No companion seen from this node yet.'), findsNothing);
    },
  );

  testWidgets(
    'stale observation (>12h) renders the "Last seen" freshness label',
    (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        _harness(
          nodeNum: 111,
          observation: RemotePetObservation(
            nodeNum: 111,
            state: _pub(),
            // 2 days ago → stale.
            observedAt: now.subtract(const Duration(days: 2)),
          ),
          lastSeen: now.subtract(const Duration(days: 2)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // Preview is rendered (we have cached state, just old).
      expect(find.byType(PetPreviewFromState), findsOneWidget);
      // Stale-emphasis label must be used, NOT the fresh-observation
      // "Observed X ago" copy.
      expect(find.text('Last seen 2d ago'), findsOneWidget);
      expect(find.text('Observed 2d ago'), findsNothing);
    },
  );

  testWidgets(
    'fresh observation (<12h) renders the "Observed" freshness label',
    (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        _harness(
          nodeNum: 112,
          observation: RemotePetObservation(
            nodeNum: 112,
            state: _pub(),
            observedAt: now.subtract(const Duration(minutes: 3)),
          ),
          lastSeen: now.subtract(const Duration(minutes: 3)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('Observed 3m ago'), findsOneWidget);
      expect(find.text('Last seen 3m ago'), findsNothing);
    },
  );

  testWidgets('observation + fresh lastSeen renders the Active band pip', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      _harness(
        nodeNum: 102,
        observation: RemotePetObservation(
          nodeNum: 102,
          state: _pub(),
          observedAt: now.subtract(const Duration(seconds: 5)),
        ),
        lastSeen: now.subtract(const Duration(seconds: 10)),
      ),
    );
    // pumpAndSettle() hangs because PetCreature's animation ticker
    // never stops — pump a few discrete frames instead so the
    // FutureProvider override resolves and the widget paints once.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    // The preview canvas is rendered.
    expect(find.byType(PetPreviewFromState), findsOneWidget);
    // Active band label.
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets(
    'observation but NO lastSeen and stale observation renders no band pip',
    (tester) async {
      // Raw band = unknown (no last-seen, stale observation).
      // The band line must NOT render.
      final now = DateTime.now();
      await tester.pumpWidget(
        _harness(
          nodeNum: 103,
          observation: RemotePetObservation(
            nodeNum: 103,
            state: _pub(),
            observedAt: now.subtract(const Duration(hours: 5)),
          ),
          lastSeen: null,
        ),
      );
      // pumpAndSettle() hangs because PetCreature's animation ticker
      // never stops — pump a few discrete frames instead so the
      // FutureProvider override resolves and the widget paints once.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // Preview is rendered (we have an observation).
      expect(find.byType(PetPreviewFromState), findsOneWidget);
      // None of the band labels should be present.
      expect(find.text('Active'), findsNothing);
      expect(find.text('Calm'), findsNothing);
      expect(find.text('Idle'), findsNothing);
      expect(find.text('Sleepy'), findsNothing);
      expect(find.text('Dormant'), findsNothing);
    },
  );

  testWidgets('observation with asleep-on-wire renders the Sleepy band pip', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      _harness(
        nodeNum: 104,
        observation: RemotePetObservation(
          nodeNum: 104,
          state: _pub(isAsleep: true),
          observedAt: now.subtract(const Duration(seconds: 2)),
        ),
        lastSeen: now.subtract(const Duration(seconds: 10)),
      ),
    );
    // pumpAndSettle() hangs because PetCreature's animation ticker
    // never stops — pump a few discrete frames instead so the
    // FutureProvider override resolves and the widget paints once.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Sleepy'), findsOneWidget);
  });

  testWidgets('observation with dormant stage renders the Dormant band pip', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      _harness(
        nodeNum: 105,
        observation: RemotePetObservation(
          nodeNum: 105,
          state: _pub(stage: PetStage.dormant),
          observedAt: now.subtract(const Duration(seconds: 2)),
        ),
        lastSeen: now.subtract(const Duration(seconds: 10)),
      ),
    );
    // pumpAndSettle() hangs because PetCreature's animation ticker
    // never stops — pump a few discrete frames instead so the
    // FutureProvider override resolves and the widget paints once.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Dormant'), findsOneWidget);
  });

  // ==========================================================================
  // Self branch — the Companion card must distinguish the user's OWN node
  // from remote peers and source from local providers, not the remote cache.
  // ==========================================================================

  group('self branch (nodeNum == myNodeNum)', () {
    PetState adultSelfState() {
      final now = DateTime.now();
      return PetState(
        ownerNodeNum: 999,
        dnaSeed: 0xabadcafe,
        stage: PetStage.adult,
        branch: PetBranch.steady,
        hatchedAt: now.subtract(const Duration(days: 3)),
        stageStartedAt: now.subtract(const Duration(days: 1)),
        lastTickAt: now,
        energy: 8,
        mood: 7,
        stability: 8,
        instability: 0,
        isSick: false,
        isAsleep: false,
        hygieneArtefacts: const [],
        activeCall: null,
        stageAccumulators: const CareAccumulators.empty(),
        recentEvents: const [],
      );
    }

    Widget selfHarness({
      required int nodeNum,
      required PetState? ownState,
      required PetPublicState? publicState,
    }) {
      return ProviderScope(
        overrides: [
          // Self-match: myNodeNum == nodeNum forces the self branch.
          myNodeNumProvider.overrideWith(() => _FakeMyNodeNum(nodeNum)),
          // Self branch reads ownPetProvider for stage/branch/age and
          // petPublicStateProvider for the preview canvas.
          ownPetProvider.overrideWith(() => _FakeOwnPet(ownState)),
          petPublicStateProvider.overrideWith((ref) => publicState),
          // Remote-side providers still need overrides because peer*
          // providers are read unconditionally by PetCreature internals
          // on some paths; keep them null/stubbed to be safe.
          peerPetObservationProvider(nodeNum).overrideWith((ref) => null),
          peerLastSeenProvider(nodeNum).overrideWith((ref) => null),
          petRemoteClientProvider.overrideWith((ref) => null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PetCompanionContent(nodeNum: nodeNum)),
        ),
      );
    }

    testWidgets(
      'own node with a local pet renders preview + Open NodePet action, NOT the unknown text',
      (tester) async {
        final state = adultSelfState();
        final public = _pub();
        await tester.pumpWidget(
          selfHarness(nodeNum: 999, ownState: state, publicState: public),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        // Local preview is rendered from petPublicStateProvider (not the
        // remote cache — that was the original bug).
        expect(find.byType(PetPreviewFromState), findsOneWidget);

        // The "Open NodePet" action must be present.
        expect(find.text('Open NodePet'), findsOneWidget);

        // The remote-empty placeholder must NOT appear for the self node.
        expect(find.text('No sigil creature observed yet.'), findsNothing);
      },
    );

    testWidgets(
      'own node with no local pet yet shows the self-empty message + Open NodePet action',
      (tester) async {
        await tester.pumpWidget(
          selfHarness(nodeNum: 999, ownState: null, publicState: null),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        // Must NOT reuse the remote "observed yet" message.
        expect(find.text('No sigil creature observed yet.'), findsNothing);

        // Must show the self-specific empty message and still offer entry.
        expect(find.text("Your companion hasn't hatched yet."), findsOneWidget);
        expect(find.text('Open NodePet'), findsOneWidget);
      },
    );
  });

  group('remote branch (nodeNum != myNodeNum)', () {
    testWidgets(
      'myNodeNum set but different from nodeNum uses remote cache (no Open NodePet button)',
      (tester) async {
        // Self node is 999 but we're viewing peer 202.
        final now = DateTime.now();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              myNodeNumProvider.overrideWith(() => _FakeMyNodeNum(999)),
              remotePetProvider(202).overrideWith(
                (ref) async => RemotePetObservation(
                  nodeNum: 202,
                  state: _pub(),
                  observedAt: now.subtract(const Duration(seconds: 5)),
                ),
              ),
              peerPetObservationProvider(202).overrideWith(
                (ref) => RemotePetObservation(
                  nodeNum: 202,
                  state: _pub(),
                  observedAt: now.subtract(const Duration(seconds: 5)),
                ),
              ),
              peerLastSeenProvider(202).overrideWith(
                (ref) => now.subtract(const Duration(seconds: 10)),
              ),
              petRemoteClientProvider.overrideWith((ref) => null),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: PetCompanionContent(nodeNum: 202)),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        // Remote preview is rendered from the cache.
        expect(find.byType(PetPreviewFromState), findsOneWidget);

        // No Open NodePet action on remote nodes — they are view-only.
        expect(find.text('Open NodePet'), findsNothing);
      },
    );
  });
}

/// Test double for [OwnPetController]. Returns the fake state straight
/// out of build() without touching the database or the care engine.
class _FakeOwnPet extends OwnPetController {
  final PetState? _state;
  _FakeOwnPet(this._state);

  @override
  Future<PetState?> build() async => _state;
}

/// Test double for [MyNodeNumNotifier]. Returns a fixed node number so
/// the self-vs-remote branch comparison in PetCompanionContent is
/// deterministic in tests.
class _FakeMyNodeNum extends MyNodeNumNotifier {
  final int _value;
  _FakeMyNodeNum(this._value);

  @override
  int? build() => _value;
}

/// Test double for [RemotePetShareStatusNotifier]. Bypasses the
/// int-arg constructor by taking a pinned status via zero-arg ctor
/// so it can be used directly with `overrideWith(() => ...)`.
class _FakeShareStatus extends RemotePetShareStatusNotifier {
  final RemotePetShareStatus _status;
  _FakeShareStatus(this._status) : super(0);

  @override
  RemotePetShareStatus build() => _status;
}
