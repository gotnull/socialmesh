// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tests for the MeshCanvas participation SharedPreferences store.
//
// Spec: docs/canvas/CANVAS_PARTICIPATION_V0_1.md §3.
//
// The store is a thin I/O surface; mutation invariants live in the
// notifier and are tested separately. Here we only verify that:
//   - missing keys default to `false` (conservative cold-install
//     state);
//   - writeSettings round-trips every combination of the three
//     booleans;
//   - reset() removes all three keys.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/services/canvas/canvas_participation_models.dart';
import 'package:socialmesh/services/canvas/canvas_participation_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MeshCanvasParticipationStore', () {
    late MeshCanvasParticipationStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = MeshCanvasParticipationStore(prefs);
    });

    test('defaults — missing keys read as (false, false, false)', () {
      expect(store.readSettings(), MeshCanvasParticipationSettings.initial);
    });

    test(
      'writeSettings round-trips (true, false, false) — local-only',
      () async {
        const next = MeshCanvasParticipationSettings(
          onboardingSeen: true,
          participationEnabled: false,
          presenceSharingEnabled: false,
        );
        await store.writeSettings(next);
        expect(store.readSettings(), next);
      },
    );

    test(
      'writeSettings round-trips (true, true, false) — joined, no sharing',
      () async {
        const next = MeshCanvasParticipationSettings(
          onboardingSeen: true,
          participationEnabled: true,
          presenceSharingEnabled: false,
        );
        await store.writeSettings(next);
        expect(store.readSettings(), next);
      },
    );

    test(
      'writeSettings round-trips (true, true, true) — joined + sharing',
      () async {
        const next = MeshCanvasParticipationSettings(
          onboardingSeen: true,
          participationEnabled: true,
          presenceSharingEnabled: true,
        );
        await store.writeSettings(next);
        expect(store.readSettings(), next);
      },
    );

    test(
      'reset() removes every key — readSettings returns initial again',
      () async {
        await store.writeSettings(
          const MeshCanvasParticipationSettings(
            onboardingSeen: true,
            participationEnabled: true,
            presenceSharingEnabled: true,
          ),
        );
        await store.reset();
        expect(store.readSettings(), MeshCanvasParticipationSettings.initial);
      },
    );
  });

  group('MeshCanvasParticipationSettings', () {
    test('equality + hashCode match by field', () {
      const a = MeshCanvasParticipationSettings(
        onboardingSeen: true,
        participationEnabled: true,
        presenceSharingEnabled: false,
      );
      const b = MeshCanvasParticipationSettings(
        onboardingSeen: true,
        participationEnabled: true,
        presenceSharingEnabled: false,
      );
      const c = MeshCanvasParticipationSettings(
        onboardingSeen: true,
        participationEnabled: true,
        presenceSharingEnabled: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('copyWith preserves untouched fields', () {
      const start = MeshCanvasParticipationSettings(
        onboardingSeen: true,
        participationEnabled: false,
        presenceSharingEnabled: false,
      );
      final next = start.copyWith(participationEnabled: true);
      expect(next.onboardingSeen, isTrue);
      expect(next.participationEnabled, isTrue);
      expect(next.presenceSharingEnabled, isFalse);
    });

    test(
      'initial constant is the conservative (false, false, false) state',
      () {
        const i = MeshCanvasParticipationSettings.initial;
        expect(i.onboardingSeen, isFalse);
        expect(i.participationEnabled, isFalse);
        expect(i.presenceSharingEnabled, isFalse);
      },
    );
  });
}
