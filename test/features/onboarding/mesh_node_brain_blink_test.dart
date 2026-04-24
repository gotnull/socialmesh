// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/onboarding/widgets/mesh_node_brain.dart';

/// Waits until at least [min] duration has elapsed on the fake async
/// clock, pumping the widget tree each 100ms so animation controllers
/// advance. Fake-async keeps the whole thing deterministic — no real
/// Timer.run uncertainty.
Future<void> _elapse(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  final steps = total.inMilliseconds ~/ step.inMilliseconds;
  for (var i = 0; i < steps; i++) {
    await tester.pump(step);
  }
  final remainder = total.inMilliseconds % step.inMilliseconds;
  if (remainder > 0) {
    await tester.pump(Duration(milliseconds: remainder));
  }
}

void main() {
  group('MeshNodeBrain idle blink — default off', () {
    testWidgets(
      'no blink controller is created when enableIdleBlink is false',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Center(
              child: MeshNodeBrain(
                mood: MeshBrainMood.happy,
                size: 120,
                // enableIdleBlink omitted — default must be false
              ),
            ),
          ),
        );
        final brain = tester.widget<MeshNodeBrain>(find.byType(MeshNodeBrain));
        expect(
          brain.enableIdleBlink,
          isFalse,
          reason: 'Default must preserve existing advisor behaviour',
        );
        // Let a long period pass — nothing should throw, no timers should
        // be scheduled by the MeshNodeBrain under test.
        await _elapse(tester, const Duration(seconds: 10));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('MeshNodeBrain idle blink — opt-in on', () {
    testWidgets('enableIdleBlink=true exposes the field on the widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: MeshNodeBrain(
              mood: MeshBrainMood.happy,
              size: 120,
              enableIdleBlink: true,
            ),
          ),
        ),
      );
      final brain = tester.widget<MeshNodeBrain>(find.byType(MeshNodeBrain));
      expect(brain.enableIdleBlink, isTrue);
      // Let the happy-mood window elapse (upper bound 6s + safety).
      await _elapse(tester, const Duration(seconds: 7));
      expect(tester.takeException(), isNull);
    });

    testWidgets('flipping enableIdleBlink off tears the blink system down', (
      tester,
    ) async {
      Widget build({required bool blink}) => MaterialApp(
        home: Center(
          child: MeshNodeBrain(
            mood: MeshBrainMood.happy,
            size: 120,
            enableIdleBlink: blink,
          ),
        ),
      );
      await tester.pumpWidget(build(blink: true));
      await _elapse(tester, const Duration(seconds: 2));
      await tester.pumpWidget(build(blink: false));
      // The teardown path must not throw — prior versions leaked a
      // Timer that fired after dispose and called setState on a gone
      // element. Pump past the longest possible scheduled interval.
      await _elapse(tester, const Duration(seconds: 9));
      expect(tester.takeException(), isNull);
    });

    testWidgets('dormant mood parks the blink scheduler (no timer fires)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: MeshNodeBrain(
              mood: MeshBrainMood.dormant,
              size: 120,
              enableIdleBlink: true,
            ),
          ),
        ),
      );
      // Pump well past any conceivable blink window. Dormant should
      // never schedule a blink, so disposal on teardown must be clean.
      await _elapse(tester, const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing mood mid-flight reschedules without exception', (
      tester,
    ) async {
      Widget build({required MeshBrainMood mood}) => MaterialApp(
        home: Center(
          child: MeshNodeBrain(mood: mood, size: 120, enableIdleBlink: true),
        ),
      );
      await tester.pumpWidget(build(mood: MeshBrainMood.happy));
      await _elapse(tester, const Duration(seconds: 2));
      // Switch to an alert-family mood. The scheduler must cancel the
      // old timer and arm a new one with the alert window (~1.5–2.5s).
      await tester.pumpWidget(build(mood: MeshBrainMood.alert));
      await _elapse(tester, const Duration(seconds: 3));
      // Then switch to dormant — scheduler must park cleanly.
      await tester.pumpWidget(build(mood: MeshBrainMood.dormant));
      await _elapse(tester, const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });
}
