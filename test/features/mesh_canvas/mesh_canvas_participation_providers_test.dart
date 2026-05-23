// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Provider-layer tests for MeshCanvas participation settings.
//
// Spec: docs/canvas/CANVAS_PARTICIPATION_V0_1.md §4 (provider graph)
// and §2.2 (mutation invariants).
//
// Coverage targets:
//   - default-load returns (false, false, false);
//   - chooseLocalOnly / joinMeshCanvas / markOnboardingSeen persist
//     the expected state shapes;
//   - setParticipationEnabled(false) forces presenceSharing off;
//   - setPresenceSharingEnabled(true) is rejected when participation
//     is off (silent no-op);
//   - cheap boolean selectors track the underlying notifier;
//   - second container reading the same prefs sees the persisted
//     decision (cold-start fidelity).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/features/mesh_canvas/providers/mesh_canvas_participation_providers.dart';
import 'package:socialmesh/services/canvas/canvas_participation_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MeshCanvasParticipationNotifier — defaults', () {
    test('initial build returns (false, false, false)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final settings = await container.read(
        meshCanvasParticipationProvider.future,
      );
      expect(settings, MeshCanvasParticipationSettings.initial);
    });

    test('boolean selectors all return false on cold start', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(meshCanvasParticipationProvider.future);
      expect(container.read(meshCanvasOnboardingSeenProvider), isFalse);
      expect(container.read(meshCanvasParticipationEnabledProvider), isFalse);
      expect(container.read(meshCanvasPresenceSharingEnabledProvider), isFalse);
    });
  });

  group('MeshCanvasParticipationNotifier — onboarding transitions', () {
    test('chooseLocalOnly persists (true, false, false)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(meshCanvasParticipationProvider.future);

      await container
          .read(meshCanvasParticipationProvider.notifier)
          .chooseLocalOnly();

      final settings = container
          .read(meshCanvasParticipationProvider)
          .asData!
          .value;
      expect(settings.onboardingSeen, isTrue);
      expect(settings.participationEnabled, isFalse);
      expect(settings.presenceSharingEnabled, isFalse);
    });

    test(
      'joinMeshCanvas persists (true, true, false) — sharing stays off',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(meshCanvasParticipationProvider.future);

        await container
            .read(meshCanvasParticipationProvider.notifier)
            .joinMeshCanvas();

        final settings = container
            .read(meshCanvasParticipationProvider)
            .asData!
            .value;
        expect(settings.onboardingSeen, isTrue);
        expect(settings.participationEnabled, isTrue);
        expect(settings.presenceSharingEnabled, isFalse);
      },
    );

    test(
      'markOnboardingSeen flips only the onboarding bit and is idempotent',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(meshCanvasParticipationProvider.future);
        final notifier = container.read(
          meshCanvasParticipationProvider.notifier,
        );

        await notifier.markOnboardingSeen();
        var settings = container
            .read(meshCanvasParticipationProvider)
            .asData!
            .value;
        expect(settings.onboardingSeen, isTrue);
        expect(settings.participationEnabled, isFalse);
        expect(settings.presenceSharingEnabled, isFalse);

        // Idempotent: second call does not regress any field.
        await notifier.markOnboardingSeen();
        settings = container
            .read(meshCanvasParticipationProvider)
            .asData!
            .value;
        expect(settings.onboardingSeen, isTrue);
        expect(settings.participationEnabled, isFalse);
        expect(settings.presenceSharingEnabled, isFalse);
      },
    );
  });

  group('MeshCanvasParticipationNotifier — mutation invariants', () {
    test('setParticipationEnabled(false) forces presenceSharing off', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(meshCanvasParticipationProvider.future);
      final notifier = container.read(meshCanvasParticipationProvider.notifier);

      // Walk through the only legal path to (true, true, true): join,
      // then explicitly enable sharing.
      await notifier.joinMeshCanvas();
      await notifier.setPresenceSharingEnabled(true);
      expect(container.read(meshCanvasPresenceSharingEnabledProvider), isTrue);

      await notifier.setParticipationEnabled(false);
      final settings = container
          .read(meshCanvasParticipationProvider)
          .asData!
          .value;
      expect(settings.participationEnabled, isFalse);
      expect(
        settings.presenceSharingEnabled,
        isFalse,
        reason: 'sharing must follow participation off',
      );
    });

    test(
      'setPresenceSharingEnabled(true) is rejected while participation off',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(meshCanvasParticipationProvider.future);
        final notifier = container.read(
          meshCanvasParticipationProvider.notifier,
        );

        await notifier.chooseLocalOnly();
        await notifier.setPresenceSharingEnabled(true);

        final settings = container
            .read(meshCanvasParticipationProvider)
            .asData!
            .value;
        expect(settings.presenceSharingEnabled, isFalse);
        expect(settings.participationEnabled, isFalse);
      },
    );

    test('setParticipationEnabled(true) does NOT auto-enable presenceSharing — '
        'sharing requires a separate explicit opt-in', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(meshCanvasParticipationProvider.future);
      final notifier = container.read(meshCanvasParticipationProvider.notifier);

      await notifier.setParticipationEnabled(true);

      final settings = container
          .read(meshCanvasParticipationProvider)
          .asData!
          .value;
      expect(settings.participationEnabled, isTrue);
      expect(settings.presenceSharingEnabled, isFalse);
    });
  });

  group('MeshCanvasParticipationNotifier — persistence across containers', () {
    test('second container reads the decision a first one wrote', () async {
      final containerA = ProviderContainer();
      addTearDown(containerA.dispose);
      await containerA.read(meshCanvasParticipationProvider.future);
      await containerA
          .read(meshCanvasParticipationProvider.notifier)
          .joinMeshCanvas();

      // Fresh container; same SharedPreferences process-singleton.
      final containerB = ProviderContainer();
      addTearDown(containerB.dispose);
      final settings = await containerB.read(
        meshCanvasParticipationProvider.future,
      );
      expect(settings.onboardingSeen, isTrue);
      expect(settings.participationEnabled, isTrue);
      expect(settings.presenceSharingEnabled, isFalse);
    });
  });

  group('MeshCanvasParticipationNotifier — selector reactivity', () {
    test('flipping participation triggers selector emit', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(meshCanvasParticipationProvider.future);

      expect(container.read(meshCanvasParticipationEnabledProvider), isFalse);
      await container
          .read(meshCanvasParticipationProvider.notifier)
          .setParticipationEnabled(true);
      expect(container.read(meshCanvasParticipationEnabledProvider), isTrue);
    });
  });
}
