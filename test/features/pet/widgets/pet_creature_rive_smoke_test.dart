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
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart';
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

    test('exactly 16 documented input names — contract does not drift', () {
      // If someone adds or removes a documented input without updating
      // PetRiveInputs, the adapter + Rive binding fall out of sync.
      // This catches that at CI time.
      final all = {
        ...kPetRiveNumberInputs,
        ...kPetRiveBoolInputs,
        ...kPetRiveTriggerInputs,
      };
      expect(
        all.length,
        kPetRiveNumberInputs.length +
            kPetRiveBoolInputs.length +
            kPetRiveTriggerInputs.length,
        reason: 'duplicate input names across the three buckets',
      );
      expect(kPetRiveNumberInputs.length, 10);
      expect(kPetRiveBoolInputs.length, 4);
      expect(kPetRiveTriggerInputs.length, 2);
      expect(all.length, 16);
    });
  });
}
