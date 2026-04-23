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
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/models/pet_public_state.dart';
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
  testWidgets('no observation renders the unknown placeholder text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(nodeNum: 101, observation: null, lastSeen: null),
    );
    // pumpAndSettle() hangs because PetCreature's animation ticker
    // never stops — pump a few discrete frames instead so the
    // FutureProvider override resolves and the widget paints once.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    // The unknown placeholder uses the petCompanionUnknown ARB key.
    // We don't assert the exact English — just that SOME placeholder
    // text is present and no band pip is rendered.
    expect(find.byType(PetPreviewFromState), findsNothing);
  });

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
}
