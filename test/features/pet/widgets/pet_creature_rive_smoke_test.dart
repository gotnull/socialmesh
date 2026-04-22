// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Smoke test for the Rive state-machine contract.
//
// Loads the shipped `assets/pet/node_pet.riv` and verifies that every
// documented input (see PetCreatureRive + NODE_PET_SYSTEM.md §9.13)
// resolves to the expected Rive input type on the canonical state
// machine. A missing or mis-typed input is the designer-facing
// equivalent of a broken API contract — this test surfaces that
// before it reaches the home screen.
//
// While the asset has not yet been authored + shipped, the test
// skips cleanly with a clear message. Once the `.riv` lands it
// starts running as a real contract check with zero further edits.

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/services/pet_rive_adapter.dart';
import 'package:socialmesh/features/pet/widgets/pet_creature_rive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PetCreatureRive — .riv state-machine contract', () {
    test('every documented input resolves on the shipped asset', () async {
      // Attempt to load the asset. Missing asset = designer hasn't
      // shipped yet; skip cleanly.
      late final RiveFile file;
      try {
        final bytes = await rootBundle.load(kPetRiveAssetPath);
        file = RiveFile.import(bytes);
      } catch (e) {
        markTestSkipped(
          '$kPetRiveAssetPath not yet present — contract test '
          'will activate once the .riv is authored. ($e)',
        );
        return;
      }

      final artboard = file.mainArtboard.instance();
      final controller = StateMachineController.fromArtboard(
        artboard,
        kPetRiveStateMachineName,
      );
      expect(
        controller,
        isNotNull,
        reason:
            'State machine "$kPetRiveStateMachineName" must exist on the '
            'main artboard "${artboard.name}". See the state-machine '
            'contract in assets/pet/README.md.',
      );
      final c = controller!;

      // --- Numbers ---
      for (final name in kPetRiveNumberInputs) {
        final input = c.findInput<double>(name);
        expect(
          input,
          isA<SMINumber>(),
          reason:
              'Number input "$name" missing or wrong type on state '
              'machine "$kPetRiveStateMachineName"',
        );
      }

      // --- Bools (non-trigger) ---
      for (final name in kPetRiveBoolInputs) {
        final input = c.findInput<bool>(name);
        expect(
          input,
          isA<SMIBool>(),
          reason:
              'Bool input "$name" missing on state machine '
              '"$kPetRiveStateMachineName"',
        );
        expect(
          input,
          isNot(isA<SMITrigger>()),
          reason:
              '"$name" must be SMIBool, not SMITrigger — wrong input '
              'type in the .riv authoring',
        );
      }

      // --- Triggers ---
      for (final name in kPetRiveTriggerInputs) {
        final input = c.findInput<bool>(name);
        expect(
          input,
          isA<SMITrigger>(),
          reason:
              'Trigger input "$name" missing on state machine '
              '"$kPetRiveStateMachineName"',
        );
      }

      controller.dispose();
    });

    testWidgets('unmount while asset load is in-flight does not crash', (
      tester,
    ) async {
      // Mount with a non-null riveInputs so _loadAndBind starts. The
      // asset load is async; we immediately unmount before it
      // completes. If the mounted-guards are wrong, this crashes.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: PetCreatureRive(
            dnaSeed: 0xdeadbeef,
            stage: PetStage.adult,
            branch: PetBranch.steady,
            mood: PetMood.content,
            isAsleep: false,
            isSick: false,
            isCalling: false,
            hygieneArtefactCount: 0,
            size: 160,
            riveInputs: const PetRiveInputs(
              stageIndex: 3,
              branchIndex: 2,
              moodIndex: 0,
              symmetryClass: 0,
              strandConfig: 0,
              signatureRotationDeg: 0,
              hygieneArtefactCount: 0,
              vitality: 1.0,
              buoyancy: 0.5,
              auraIntensity: 0.5,
              isAsleep: false,
              isSick: false,
              isCalling: false,
              hasAnomaly: false,
            ),
          ),
        ),
      );

      // Replace with an empty tree before the load future resolves.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );

      // Let any pending microtasks / timers drain — including the
      // look-ticker, if _startLookTicker happened to run before dispose.
      await tester.pump(const Duration(milliseconds: 16));
      // No FlutterError / test failure = mounted-guards and ticker
      // disposal did their job.
    });

    testWidgets(
      'fallback mode mounts + unmounts cleanly (no Rive load attempted)',
      (tester) async {
        // riveInputs: null triggers the fallback path — no _loadAndBind,
        // no Ticker allocation. Must mount + unmount without crashing.
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: PetCreatureRive(
              dnaSeed: 0xcafebabe,
              stage: PetStage.juvenile,
              branch: PetBranch.unborn,
              mood: PetMood.content,
              isAsleep: false,
              isSick: false,
              isCalling: false,
              hygieneArtefactCount: 0,
              size: 120,
            ),
          ),
        );
        // Fallback renders PetCreature custom painter — pump once to
        // settle.
        await tester.pump();

        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox.shrink(),
          ),
        );
        await tester.pump();
      },
    );

    test('exactly 18 documented input names — contract does not drift', () {
      // If someone adds or removes a documented input without updating
      // PetRiveInputs, the adapter + Rive binding fall out of sync.
      // This catches that at CI time.
      final all = {
        ...kPetRiveNumberInputs,
        ...kPetRiveBoolInputs,
        ...kPetRiveTriggerInputs,
        ...kPetRiveOptionalNumberInputs,
      };
      expect(
        all.length,
        kPetRiveNumberInputs.length +
            kPetRiveBoolInputs.length +
            kPetRiveTriggerInputs.length +
            kPetRiveOptionalNumberInputs.length,
        reason: 'duplicate input names across the input buckets',
      );
      expect(kPetRiveNumberInputs.length, 10);
      expect(kPetRiveBoolInputs.length, 4);
      expect(kPetRiveTriggerInputs.length, 2);
      // Optional look inputs — eye tracking / gaze direction.
      expect(kPetRiveOptionalNumberInputs, containsAll(['lookX', 'lookY']));
      expect(kPetRiveOptionalNumberInputs.length, 2);
      expect(all.length, 18);
    });
  });
}
