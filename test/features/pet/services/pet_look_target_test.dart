// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tests for the pointer → Rive look-input mapping boundary.
//
// Invariants pinned:
//   - Local widget-space mapping to 0..100 is correct and clamped.
//   - Idle (no pointer) and sleeping / dormant states neutralise to
//     (50, 50) regardless of any prior activity.
//   - Sick reduces the tracked range around centre.
//   - Calling slightly amplifies the tracked range.
//   - Priority: sick dampens even while calling.
//   - Smoother settles at target and reports material writes.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/services/pet_look_target.dart';

({double dx, double dy}) _p(double x, double y) => (dx: x, dy: y);

void main() {
  const resolver = PetLookTargetResolver();

  group('PetLookTargetResolver — local position mapping', () {
    test('centre maps to (50, 50)', () {
      final t = resolver.resolve(
        localPointer: _p(100, 100),
        size: 200,
        isAsleep: false,
        isSick: false,
        isCalling: false,
        stage: PetStage.adult,
      );
      expect(t.x, closeTo(50.0, 1e-9));
      expect(t.y, closeTo(50.0, 1e-9));
    });

    test('top-left corner maps to (0, 0) at content range', () {
      final t = resolver.resolve(
        localPointer: _p(0, 0),
        size: 200,
        isAsleep: false,
        isSick: false,
        isCalling: false,
        stage: PetStage.adult,
      );
      expect(t.x, 0.0);
      expect(t.y, 0.0);
    });

    test('bottom-right corner maps to (100, 100) at content range', () {
      final t = resolver.resolve(
        localPointer: _p(200, 200),
        size: 200,
        isAsleep: false,
        isSick: false,
        isCalling: false,
        stage: PetStage.adult,
      );
      expect(t.x, 100.0);
      expect(t.y, 100.0);
    });

    test('out-of-bounds pointer is clamped to [0, 100]', () {
      final tOver = resolver.resolve(
        localPointer: _p(400, 400),
        size: 200,
        isAsleep: false,
        isSick: false,
        isCalling: false,
        stage: PetStage.adult,
      );
      final tUnder = resolver.resolve(
        localPointer: _p(-50, -50),
        size: 200,
        isAsleep: false,
        isSick: false,
        isCalling: false,
        stage: PetStage.adult,
      );
      expect(tOver.x, 100.0);
      expect(tOver.y, 100.0);
      expect(tUnder.x, 0.0);
      expect(tUnder.y, 0.0);
    });

    test('non-positive size short-circuits to centre', () {
      final t = resolver.resolve(
        localPointer: _p(50, 50),
        size: 0,
        isAsleep: false,
        isSick: false,
        isCalling: false,
        stage: PetStage.adult,
      );
      expect(t, PetLookTarget.center);
    });
  });

  group('PetLookTargetResolver — idle / suppression states', () {
    test('no active pointer returns centre', () {
      final t = resolver.resolve(
        localPointer: null,
        size: 200,
        isAsleep: false,
        isSick: false,
        isCalling: false,
        stage: PetStage.adult,
      );
      expect(t, PetLookTarget.center);
    });

    test('sleeping suppresses tracking regardless of pointer', () {
      final t = resolver.resolve(
        localPointer: _p(0, 0),
        size: 200,
        isAsleep: true,
        isSick: false,
        isCalling: false,
        stage: PetStage.adult,
      );
      expect(t, PetLookTarget.center);
    });

    test('dormant stage suppresses tracking regardless of pointer', () {
      final t = resolver.resolve(
        localPointer: _p(200, 200),
        size: 200,
        isAsleep: false,
        isSick: false,
        isCalling: true,
        stage: PetStage.dormant,
      );
      expect(t, PetLookTarget.center);
    });
  });

  group('PetLookTargetResolver — state-driven range modulation', () {
    test('sick reduces range so edge pointer does NOT hit 0/100', () {
      final t = resolver.resolve(
        localPointer: _p(200, 200),
        size: 200,
        isAsleep: false,
        isSick: true,
        isCalling: false,
        stage: PetStage.adult,
      );
      expect(t.x, greaterThan(50.0));
      expect(t.x, lessThan(100.0));
      expect(t.y, greaterThan(50.0));
      expect(t.y, lessThan(100.0));
    });

    test('calling amplifies range but still clamps to [0, 100]', () {
      final healthy = resolver.resolve(
        localPointer: _p(200, 200),
        size: 200,
        isAsleep: false,
        isSick: false,
        isCalling: false,
        stage: PetStage.adult,
      );
      final calling = resolver.resolve(
        localPointer: _p(200, 200),
        size: 200,
        isAsleep: false,
        isSick: false,
        isCalling: true,
        stage: PetStage.adult,
      );
      // Edge pointer: healthy saturates at 100; calling also clamps.
      expect(healthy.x, 100.0);
      expect(calling.x, 100.0);

      // At a sub-edge pointer the calling range is measurably stronger.
      final nearEdgeHealthy = resolver.resolve(
        localPointer: _p(180, 100),
        size: 200,
        isAsleep: false,
        isSick: false,
        isCalling: false,
        stage: PetStage.adult,
      );
      final nearEdgeCalling = resolver.resolve(
        localPointer: _p(180, 100),
        size: 200,
        isAsleep: false,
        isSick: false,
        isCalling: true,
        stage: PetStage.adult,
      );
      expect(nearEdgeCalling.x, greaterThan(nearEdgeHealthy.x));
    });

    test('sick priority wins over calling — dampened even when calling', () {
      final sickCalling = resolver.resolve(
        localPointer: _p(200, 100),
        size: 200,
        isAsleep: false,
        isSick: true,
        isCalling: true,
        stage: PetStage.adult,
      );
      final healthyCalling = resolver.resolve(
        localPointer: _p(200, 100),
        size: 200,
        isAsleep: false,
        isSick: false,
        isCalling: true,
        stage: PetStage.adult,
      );
      expect(sickCalling.x, lessThan(healthyCalling.x));
    });
  });

  group('PetLookTarget — equality', () {
    test('same coords compare equal', () {
      expect(const PetLookTarget(12, 34), const PetLookTarget(12, 34));
      expect(
        const PetLookTarget(12, 34).hashCode,
        const PetLookTarget(12, 34).hashCode,
      );
    });

    test('center is (50, 50)', () {
      expect(PetLookTarget.center.x, 50.0);
      expect(PetLookTarget.center.y, 50.0);
    });
  });

  group('PetLookSmoother — easing toward target', () {
    test('starts at centre', () {
      final s = PetLookSmoother();
      expect(s.currentX, 50.0);
      expect(s.currentY, 50.0);
    });

    test('monotonically approaches target', () {
      final s = PetLookSmoother();
      const target = PetLookTarget(100.0, 0.0);
      double lastX = s.currentX;
      double lastY = s.currentY;
      for (var i = 0; i < 30; i++) {
        s.tick(target: target, sluggish: false);
        expect(s.currentX, greaterThanOrEqualTo(lastX));
        expect(s.currentY, lessThanOrEqualTo(lastY));
        lastX = s.currentX;
        lastY = s.currentY;
      }
    });

    test('settles exactly on target after enough ticks', () {
      final s = PetLookSmoother();
      const target = PetLookTarget(80.0, 20.0);
      for (var i = 0; i < 120; i++) {
        s.tick(target: target, sluggish: false);
      }
      expect(s.currentX, closeTo(80.0, 0.5));
      expect(s.currentY, closeTo(20.0, 0.5));
    });

    test('resetToCenter snaps back to (50, 50)', () {
      final s = PetLookSmoother();
      for (var i = 0; i < 10; i++) {
        s.tick(target: const PetLookTarget(100, 100), sluggish: false);
      }
      s.resetToCenter();
      expect(s.currentX, 50.0);
      expect(s.currentY, 50.0);
    });

    test('first tick from centre to a far target reports material change', () {
      final s = PetLookSmoother();
      final material = s.tick(
        target: const PetLookTarget(100.0, 100.0),
        sluggish: false,
      );
      expect(material, isTrue);
    });

    test('tick at the target is not material', () {
      final s = PetLookSmoother();
      final material = s.tick(target: PetLookTarget.center, sluggish: false);
      expect(material, isFalse);
    });

    test('sluggish lerp converges slower than the default', () {
      final fast = PetLookSmoother();
      final slow = PetLookSmoother();
      const target = PetLookTarget(100.0, 100.0);
      for (var i = 0; i < 5; i++) {
        fast.tick(target: target, sluggish: false);
        slow.tick(target: target, sluggish: true);
      }
      expect(fast.currentX, greaterThan(slow.currentX));
    });
  });
}
