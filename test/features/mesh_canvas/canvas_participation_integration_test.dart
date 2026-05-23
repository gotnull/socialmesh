// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas participation — S7 integration + invariant regression
// tests.
//
// Spec: docs/canvas/CANVAS_PARTICIPATION_V0_1.md §8 (hard invariants
// I1-I6) + §10 (full test matrix).
//
// This file ties the per-slice tests together into end-to-end
// scenarios and pins the static-source invariants that CI must
// enforce going forward.
//
// Coverage:
//   - I1 No auto-enable: static grep proves no file outside the
//     participation feature calls setParticipationEnabled(true) or
//     setPresenceSharingEnabled(true).
//   - I6 MeshCore independence: static grep proves the MeshCore
//     shell does not import any participation files.
//   - End-to-end provider walk: fresh prefs → onboarding → Explore
//     locally → Mesh tab disabled → enable via settings → settings
//     reads back the expected combinations.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/features/mesh_canvas/providers/mesh_canvas_participation_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('participation invariants — static-grep regression pins', () {
    test('I1 — only the participation feature itself calls '
        'setParticipationEnabled(true) or joinMeshCanvas / chooseLocalOnly. '
        'Auto-enable from any other module is a critical regression.', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'test expects lib/ on disk');
      final offenders = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.dart')) continue;
        // The feature files are allowed to mutate; everything else
        // is not.
        if (entity.path.contains(
          'lib/features/mesh_canvas/widgets/canvas_participation_',
        )) {
          continue;
        }
        if (entity.path.contains(
          'lib/features/mesh_canvas/screens/mesh_canvas_overview_screen',
        )) {
          // Overview screen reads the providers but never calls
          // the opinionated mutators — it delegates via widgets.
          continue;
        }
        // The notifier itself is allowed.
        if (entity.path.endsWith('mesh_canvas_participation_providers.dart')) {
          continue;
        }
        final src = entity.readAsStringSync();
        if (src.contains('setParticipationEnabled(true)') ||
            src.contains('setPresenceSharingEnabled(true)') ||
            src.contains('joinMeshCanvas()') ||
            src.contains('chooseLocalOnly()')) {
          offenders.add(entity.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'I1 — no module outside the participation feature may call the '
            'opt-in mutators directly. Offenders: $offenders',
      );
    });

    test(
      'I6 — MeshCore shell does NOT import any participation feature file',
      () {
        final meshCoreShell = File(
          'lib/features/navigation/meshcore_shell.dart',
        );
        expect(meshCoreShell.existsSync(), isTrue);
        final src = meshCoreShell.readAsStringSync();
        expect(
          src.contains('canvas_participation_'),
          isFalse,
          reason:
              'I6 — MeshCore shell must not import any MeshCanvas '
              'participation file. Feature is Meshtastic-only.',
        );
        expect(
          src.contains('mesh_canvas_participation_providers'),
          isFalse,
          reason: 'I6 — same as above for the providers file.',
        );
      },
    );
  });

  group('participation — end-to-end provider walk', () {
    test(
      'fresh install → Explore locally → enable participation via settings → '
      'enable sharing — every state transition is consistent',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Step 1: fresh install. Default settings.
        var settings = await container.read(
          meshCanvasParticipationProvider.future,
        );
        expect(settings.onboardingSeen, isFalse);
        expect(settings.participationEnabled, isFalse);
        expect(settings.presenceSharingEnabled, isFalse);

        // Step 2: user taps Explore locally on the onboarding sheet.
        await container
            .read(meshCanvasParticipationProvider.notifier)
            .chooseLocalOnly();
        settings = container
            .read(meshCanvasParticipationProvider)
            .asData!
            .value;
        expect(settings.onboardingSeen, isTrue);
        expect(settings.participationEnabled, isFalse);
        expect(settings.presenceSharingEnabled, isFalse);

        // Step 3: user enables participation via the calm CTA card on
        // the Mesh tab.
        await container
            .read(meshCanvasParticipationProvider.notifier)
            .setParticipationEnabled(true);
        settings = container
            .read(meshCanvasParticipationProvider)
            .asData!
            .value;
        expect(settings.onboardingSeen, isTrue);
        expect(settings.participationEnabled, isTrue);
        expect(
          settings.presenceSharingEnabled,
          isFalse,
          reason: 'enabling participation must NOT auto-enable sharing',
        );

        // Step 4: user opens settings, enables presence sharing.
        await container
            .read(meshCanvasParticipationProvider.notifier)
            .setPresenceSharingEnabled(true);
        settings = container
            .read(meshCanvasParticipationProvider)
            .asData!
            .value;
        expect(settings.participationEnabled, isTrue);
        expect(settings.presenceSharingEnabled, isTrue);

        // Step 5: user disables participation. Sharing must follow.
        await container
            .read(meshCanvasParticipationProvider.notifier)
            .setParticipationEnabled(false);
        settings = container
            .read(meshCanvasParticipationProvider)
            .asData!
            .value;
        expect(settings.participationEnabled, isFalse);
        expect(
          settings.presenceSharingEnabled,
          isFalse,
          reason: 'disabling participation must force sharing off (invariant)',
        );

        // Step 6: re-enable participation. Sharing remains off — the
        // user must explicitly opt in again, prior toggle is not
        // restored.
        await container
            .read(meshCanvasParticipationProvider.notifier)
            .setParticipationEnabled(true);
        settings = container
            .read(meshCanvasParticipationProvider)
            .asData!
            .value;
        expect(settings.participationEnabled, isTrue);
        expect(
          settings.presenceSharingEnabled,
          isFalse,
          reason:
              're-enabling participation must NOT restore the prior sharing '
              'state — the user explicitly disabled it, even transitively',
        );
      },
    );
  });
}
